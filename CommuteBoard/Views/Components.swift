import SwiftUI

extension Color {
    static let subwayRed = Color(red: 0.93, green: 0.21, blue: 0.18)   // MTA 7th Ave line red
    static let busBlue = Color(red: 0.0, green: 0.22, blue: 0.65)
    static let ebikeGreen = Color(red: 0.15, green: 0.68, blue: 0.38)
    static let columbiaBlue = Color(red: 0.73, green: 0.85, blue: 0.92)
    static let columbiaNavy = Color(red: 0.0, green: 0.2, blue: 0.4)
}

/// The round subway bullet, a rounded "M4" bus tag, or a Columbia-blue "CU" shuttle tag.
struct RouteBadge: View {
    let route: String
    let kind: Board.Kind
    var size: CGFloat = 30

    var body: some View {
        Text(route)
            .font(.system(size: size * (kind == .subway ? 0.6 : 0.42), weight: .bold, design: .rounded))
            .foregroundStyle(kind == .shuttle ? Color.columbiaNavy : .white)
            .frame(minWidth: size, minHeight: size)
            .padding(.horizontal, kind == .subway ? 0 : 4)
            .background(background, in: RoundedRectangle(cornerRadius: kind == .subway ? size / 2 : 6))
            .accessibilityLabel(accessibilityText)
    }

    private var background: Color {
        switch kind {
        case .subway: .subwayRed
        case .bus: .busBlue
        case .shuttle: .columbiaBlue
        }
    }

    private var accessibilityText: String {
        switch kind {
        case .subway: "\(route) train"
        case .bus: "\(route) bus"
        case .shuttle: "Columbia shuttle"
        }
    }
}

/// Section header: just the mode icon, plus a pin button that pops up the stop's address.
struct BoardHeader: View {
    let board: Board
    @State private var showingLocation = false

    var body: some View {
        HStack {
            Image(systemName: board.kind.systemImage)
                .font(.subheadline)
                .accessibilityLabel("\(board.kind.label), \(board.stopName)")
            Spacer()
            Button {
                showingLocation = true
            } label: {
                Image(systemName: "mappin.circle")
                    .font(.body)
                    .frame(width: 32, height: 28, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Stop location")
            .popover(isPresented: $showingLocation) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(board.stopName, systemImage: "mappin.and.ellipse")
                        .font(.headline)
                    Link(destination: DockDetailView.walkingDirectionsURL(to: board.coordinate)) {
                        Label("Walking directions", systemImage: "figure.walk")
                            .font(.subheadline)
                    }
                }
                .padding()
                .presentationCompactAdaptation(.popover)
            }
        }
    }
}

/// Main-screen row: next arrival large, the following ones as "then 9, 15 min".
struct TransitSummaryRow: View {
    let board: Board
    let arrivals: [Arrival]
    let now: Date
    let emptyText: String

    var body: some View {
        HStack(spacing: 12) {
            // Fixed-width badge column so "Uptown" / "Downtown" line up across cards.
            RouteBadge(route: arrivals.first?.route ?? board.badgeText, kind: board.kind)
                .opacity(arrivals.isEmpty ? 0.4 : 1)
                .frame(width: Self.badgeColumnWidth, alignment: .leading)
            Text(board.direction)
                .font(.headline)
            Spacer(minLength: 8)
            if let next = arrivals.first {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(next.minutesText(now: now))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(next.arrivalTime == nil ? .secondary : .primary)
                    if let following = followingText {
                        Text(following)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: Self.rowHeight)
    }

    static let badgeColumnWidth: CGFloat = 40
    /// Shared by transit and dock rows so every card is the same height whether or not it has data.
    static let rowHeight: CGFloat = 52

    private var followingText: String? {
        let minutes = arrivals.dropFirst().prefix(2).compactMap { $0.minutes(now: now) }
        guard !minutes.isEmpty else { return nil }
        return "then " + minutes.map(String.init).joined(separator: ", ") + " min"
    }
}

/// One arrival in a detail list.
struct ArrivalRow: View {
    let arrival: Arrival
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            RouteBadge(route: arrival.route, kind: arrival.kind, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(arrival.destination)
                        .font(.headline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if arrival.isLimited {
                        Text("LTD")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.busBlue.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.busBlue)
                    }
                }
                if let detail = arrival.detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(arrival.minutesText(now: now))
                    .font(.title3.bold().monospacedDigit())
                if let time = arrival.arrivalTime {
                    Text(time, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Main-screen row for a Citi Bike dock.
struct DockRow: View {
    let dock: BikeDock
    let isStale: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dock.nickname)
                    .font(.headline)
                if let badge = dock.status.badge {
                    StatusBadge(text: badge, color: dock.status.color)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 14) {
                CountColumn(value: dock.ebikes, systemImage: "bolt.fill", label: "E-bike", tint: .ebikeGreen)
                CountColumn(value: dock.classicBikes, systemImage: "bicycle", label: "Classic", tint: .busBlue)
                CountColumn(value: dock.openDocks, systemImage: "parkingsign.circle", label: "Docks", tint: .secondary)
            }
            .opacity(isStale ? 0.45 : 1)
        }
        .frame(minHeight: TransitSummaryRow.rowHeight)
    }
}

struct CountColumn: View {
    let value: Int
    let systemImage: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(value == 0 ? .secondary : .primary)
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(tint)
        }
        .frame(minWidth: 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

extension BikeDock.Status {
    var color: Color {
        switch self {
        case .available: .ebikeGreen
        case .low: .orange
        case .empty, .full: .red
        case .offline: .gray
        }
    }
}

/// Section footer: "Updated 20s ago", or the error plus how old the saved data is.
struct UpdatedFooter: View {
    let fetchedAt: Date?
    let error: String?
    let isOffline: Bool
    let now: Date

    var body: some View {
        if let error, !isOffline {
            VStack(alignment: .leading, spacing: 2) {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                if let fetchedAt {
                    Text("Showing data from \(fetchedAt.formatted(date: .omitted, time: .shortened))")
                }
            }
        } else if let fetchedAt {
            Text(isOffline ? "Saved \(Self.age(of: fetchedAt, now: now))" : "Updated \(Self.age(of: fetchedAt, now: now))")
        }
    }

    static func age(of date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<10: return "just now"
        case ..<60: return "\(seconds)s ago"
        case ..<3600: return "\(seconds / 60) min ago"
        default: return "at " + date.formatted(date: .abbreviated, time: .shortened)
        }
    }
}

struct OfflineBanner: View {
    let savedAt: Date?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.headline)
            VStack(alignment: .leading, spacing: 1) {
                Text("You're offline")
                    .font(.subheadline.bold())
                Text(savedAt.map { "Showing saved data from \($0.formatted(date: .omitted, time: .shortened)). Times are estimates." }
                     ?? "No saved data yet.")
                    .font(.caption)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 12))
    }
}
