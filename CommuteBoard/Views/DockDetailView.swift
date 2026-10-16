import SwiftUI
import MapKit

/// Map plus a full breakdown of one Citi Bike dock.
struct DockDetailView: View {
    @Environment(CommuteStore.self) private var store

    let dock: BikeDock
    let place: Place

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let isStale = store.isStale(store.snapshot.docksFetchedAt, now: context.date)
            List {
                Section {
                    map
                        .frame(height: 240)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    HStack {
                        Circle()
                            .fill(dock.status.color)
                            .frame(width: 12, height: 12)
                        Text(dock.status.label)
                            .font(.title3.bold())
                        Spacer()
                        Text("\(dock.capacity) total docks")
                            .foregroundStyle(.secondary)
                    }
                    CapacityBar(dock: dock)
                        .frame(height: 28)
                        .padding(.vertical, 4)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(value: dock.ebikes, label: "E-bikes", systemImage: "bolt.fill", tint: .ebikeGreen)
                        StatTile(value: dock.classicBikes, label: "Classic bikes", systemImage: "bicycle", tint: .busBlue)
                        StatTile(value: dock.openDocks, label: "Open docks", systemImage: "parkingsign.circle", tint: .secondary)
                        StatTile(value: dock.disabledBikes + dock.disabledDocks, label: "Out of service", systemImage: "wrench.fill", tint: .gray)
                    }
                    .padding(.vertical, 4)
                    .opacity(isStale ? 0.5 : 1)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dock last reported \(UpdatedFooter.age(of: dock.lastReported, now: context.date)).")
                        if isStale {
                            Text("These counts are from saved data and may have changed.")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    LabeledContent("Official name", value: dock.officialName)
                    if let coordinate = dock.coordinate {
                        Link(destination: Self.walkingDirectionsURL(to: coordinate)) {
                            Label("Walking directions", systemImage: "figure.walk")
                        }
                    }
                }
            }
        }
        .navigationTitle(dock.nickname)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh([place]) }
    }

    @ViewBuilder
    private var map: some View {
        if let coordinate = dock.coordinate {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
            ))) {
                ForEach(place.docks) { other in
                    Marker(other.nickname, systemImage: "bicycle", coordinate: other.coordinate)
                        .tint(other.id == dock.id ? dock.status.color : .gray)
                }
                ForEach(transitStops, id: \.id) { board in
                    Marker(board.stopName, systemImage: board.kind.systemImage, coordinate: board.coordinate)
                        .tint(Self.tint(for: board.kind))
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
        }
    }

    /// One marker per physical stop (e.g. both platforms of a station share one).
    private var transitStops: [Board] {
        var seen = Set<String>()
        return place.boards.filter { seen.insert("\($0.kind)-\($0.stopName)").inserted }
    }

    private static func tint(for kind: Board.Kind) -> Color {
        switch kind {
        case .subway: .subwayRed
        case .bus: .busBlue
        case .shuttle: .columbiaNavy
        }
    }

    static func walkingDirectionsURL(to coordinate: CLLocationCoordinate2D) -> URL {
        URL(string: "https://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)&dirflg=w")!
    }
}

/// Horizontal bar showing how the dock's slots are split up. Each segment carries its
/// icon and count, so it reads without relying on color.
private struct CapacityBar: View {
    let dock: BikeDock

    private struct Segment: Identifiable {
        let id: String
        let count: Int
        let systemImage: String
        let fill: Color
        let foreground: Color
    }

    private var segments: [Segment] {
        [
            Segment(id: "ebike", count: dock.ebikes, systemImage: "bolt.fill", fill: .ebikeGreen, foreground: .white),
            Segment(id: "classic", count: dock.classicBikes, systemImage: "bicycle", fill: .busBlue, foreground: .white),
            Segment(id: "broken", count: dock.disabledBikes + dock.disabledDocks, systemImage: "wrench.fill", fill: .gray, foreground: .white),
            Segment(id: "open", count: dock.openDocks, systemImage: "parkingsign.circle", fill: Color(.systemGray5), foreground: .secondary),
        ].filter { $0.count > 0 }
    }

    var body: some View {
        GeometryReader { geometry in
            let visible = segments
            let total = CGFloat(max(1, visible.reduce(0) { $0 + $1.count }))
            let usable = geometry.size.width - CGFloat(max(0, visible.count - 1)) * 2
            HStack(spacing: 2) {
                ForEach(visible) { segment in
                    let width = usable * CGFloat(segment.count) / total
                    ZStack {
                        Rectangle().fill(segment.fill)
                        // Icon + count when there's room, icon alone when tight, nothing when tiny.
                        if width >= 40 {
                            HStack(spacing: 3) {
                                Image(systemName: segment.systemImage)
                                Text("\(segment.count)").monospacedDigit()
                            }
                        } else if width >= 18 {
                            Image(systemName: segment.systemImage)
                        }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(segment.foreground)
                    .frame(width: width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .accessibilityHidden(true)
    }
}

private struct StatTile: View {
    let value: Int
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.largeTitle.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
