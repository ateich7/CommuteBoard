import SwiftUI

enum PlaceRoute: Hashable {
    case board(String)
    case dock(String)
}

/// The list for one tab: a section per train/bus/shuttle board, then the nearby docks.
struct PlaceView: View {
    @Environment(CommuteStore.self) private var store
    @State private var showingSettings = false
    @State private var path: [PlaceRoute]

    let place: Place

    init(place: Place) {
        self.place = place
        _path = State(initialValue: Self.initialPath(for: place))
    }

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.periodic(from: .now, by: 5)) { context in
                list(now: context.date)
                    .safeAreaInset(edge: .top, spacing: 0) { header(now: context.date) }
            }
            // The title lives in the custom header; keep it here for the back button.
            .navigationTitle(place.name)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PlaceRoute.self) { route in
                destination(for: route)
            }
            .overlay {
                if !store.snapshot.hasData(for: place) && store.isOffline {
                    ContentUnavailableView(
                        "No Saved Data Yet",
                        systemImage: "wifi.slash",
                        description: Text("Connect once to load arrivals. After that, the app keeps working offline.")
                    )
                }
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: { Task { await store.refresh([place]) } }) {
            SettingsView()
        }
        // Runs while this tab is visible; switching tabs cancels it.
        .task { await store.autoRefresh(place) }
    }

    private func list(now: Date) -> some View {
        let snapshot = store.snapshot
        let pageUpdated = snapshot.latestFetch(for: place)
        return List {
            if store.isOffline {
                OfflineBanner(savedAt: snapshot.oldestFetch(for: place))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            ForEach(Self.groups(for: place), id: \.id) { group in
                Section {
                    ForEach(group.boards) { board in
                        boardRow(board, now: now)
                    }
                } header: {
                    BoardHeader(board: group.boards[0])
                } footer: {
                    sectionStatus(fetchedAt: group.boards.compactMap { snapshot.fetchedAt(for: $0) }.min(),
                                  error: group.boards.lazy.compactMap { store.errors[$0.id] }.first,
                                  pageUpdated: pageUpdated, now: now)
                }
            }

            Section {
                let docks = place.docks.compactMap { snapshot.docks[$0.id] }
                if docks.isEmpty {
                    Text(snapshot.docksFetchedAt == nil ? "Loading…" : "Docks not found in Citi Bike feed")
                        .foregroundStyle(.secondary)
                }
                ForEach(docks) { dock in
                    NavigationLink(value: PlaceRoute.dock(dock.id)) {
                        DockRow(dock: dock, isStale: store.isStale(snapshot.docksFetchedAt, now: now))
                    }
                }
            } header: {
                Image(systemName: "bicycle")
                    .font(.subheadline)
                    .accessibilityLabel("Citi Bike")
            } footer: {
                sectionStatus(fetchedAt: snapshot.docksFetchedAt, error: store.bikeError,
                              pageUpdated: pageUpdated, now: now)
            }
        }
        .listSectionSpacing(12)
        .contentMargins(.top, 4, for: .scrollContent)
        .refreshable { await store.refresh([place]) }
        .animation(.default, value: store.isOffline)
    }

    /// Sticky one-line header: the place name, the page's single "Updated…" timestamp, and Settings.
    /// Sections only add their own timestamp when they lag behind this one.
    private func header(now: Date) -> some View {
        let pageUpdated = store.snapshot.latestFetch(for: place)
        return HStack(alignment: .center, spacing: 12) {
            Text(place.name)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let pageUpdated, !store.isOffline {
                Text("Updated \(UpdatedFooter.age(of: pageUpdated, now: now))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button("Settings", systemImage: "gearshape") { showingSettings = true }
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }

    /// A section's own "Updated…" line, shown only when it differs from the page:
    /// its last refresh failed, or its data is more than a minute older.
    @ViewBuilder
    private func sectionStatus(fetchedAt: Date?, error: String?, pageUpdated: Date?, now: Date) -> some View {
        let failed = error != nil && !store.isOffline
        let lagging = fetchedAt.flatMap { fetched in pageUpdated.map { $0.timeIntervalSince(fetched) > 60 } } ?? false
        if fetchedAt != nil, failed || lagging {
            UpdatedFooter(fetchedAt: fetchedAt, error: error, isOffline: store.isOffline, now: now)
        } else if fetchedAt == nil, failed {
            Label(error ?? "", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func boardRow(_ board: Board, now: Date) -> some View {
        let snapshot = store.snapshot
        let fetchedAt = snapshot.fetchedAt(for: board)
        if board.kind == .bus, fetchedAt == nil, store.errors[board.id] != nil {
            // Most likely no API key yet — point straight at Settings.
            Button {
                showingSettings = true
            } label: {
                Label("Add your Bus Time API key", systemImage: "key.fill")
            }
        } else {
            NavigationLink(value: PlaceRoute.board(board.id)) {
                TransitSummaryRow(
                    board: board,
                    arrivals: snapshot.arrivals(for: board).upcoming(now: now, fetchedAt: fetchedAt),
                    now: now,
                    emptyText: fetchedAt == nil ? "Loading…" : Self.emptyText(for: board)
                )
            }
        }
    }

    @ViewBuilder
    private func destination(for route: PlaceRoute) -> some View {
        switch route {
        case .board(let id):
            if let board = place.boards.first(where: { $0.id == id }) {
                ArrivalsDetailView(board: board, place: place)
            }
        case .dock(let id):
            if let dock = store.snapshot.docks[id] {
                DockDetailView(dock: dock, place: place)
            } else {
                ContentUnavailableView("Dock Unavailable", systemImage: "bicycle")
            }
        }
    }

    /// Boards of the same kind at the same stop (e.g. uptown and downtown 1 at 116 St)
    /// share one section, so the header icon and location pin appear once.
    struct BoardGroup {
        let id: String
        var boards: [Board]
    }

    static func groups(for place: Place) -> [BoardGroup] {
        var groups: [BoardGroup] = []
        for board in place.boards {
            let key = "\(board.kind.rawValue)|\(board.stopName)"
            if let index = groups.firstIndex(where: { $0.id == key }) {
                groups[index].boards.append(board)
            } else {
                groups.append(BoardGroup(id: key, boards: [board]))
            }
        }
        return groups
    }

    static func emptyText(for board: Board) -> String {
        switch board.kind {
        case .subway: "None stopping"
        case .bus: "None coming"
        case .shuttle: "None today"
        }
    }

    /// Debug launch argument for jumping straight to a screen: -openRoute board|board2|dock
    private static func initialPath(for place: Place) -> [PlaceRoute] {
        #if DEBUG
        guard UserDefaults.standard.string(forKey: "selectedTab") ?? Config.home.id == place.id else { return [] }
        let route = UserDefaults.standard.string(forKey: "openRoute") ?? ""
        if route == "dock" { return place.docks.first.map { [.dock($0.id)] } ?? [] }
        // "board" opens the first board, "board3" the fourth.
        if route.hasPrefix("board") {
            let index = Int(route.dropFirst(5)) ?? 0
            return place.boards.indices.contains(index) ? [.board(place.boards[index].id)] : []
        }
        return []
        #else
        return []
        #endif
    }
}
