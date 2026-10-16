import Foundation
import Observation

/// Owns the app's data: loads the cached snapshot on launch, refreshes sources in
/// parallel, and saves whatever succeeded back to disk.
@MainActor
@Observable
final class CommuteStore {
    private(set) var snapshot: CommuteSnapshot
    /// Last error per Board.id; cleared on the next success.
    private(set) var errors: [String: String] = [:]
    private(set) var bikeError: String?
    private var currentRefresh: Task<Void, Never>?
    private var hasRefreshedAll = false

    var isRefreshing: Bool { currentRefresh != nil }

    let network = NetworkMonitor()

    init() {
        snapshot = SnapshotCache.load() ?? CommuteSnapshot()
    }

    var isOffline: Bool { !network.isConnected }

    /// Refreshes the given places' boards plus all Citi Bike docks (one shared request).
    /// Only the visible tab is refreshed on the timer, to go easy on the Bus Time API.
    func refresh(_ places: [Place]) async {
        // One refresh at a time; a request made mid-refresh (e.g. switching tabs) waits its turn.
        while let running = currentRefresh {
            await running.value
        }
        // Offline: skip the requests (they'd just time out) and keep showing the cache.
        guard network.isConnected else { return }

        let task = Task {
            await performRefresh(places)
            currentRefresh = nil
        }
        currentRefresh = task
        await task.value
    }

    private func performRefresh(_ places: [Place]) async {
        var seen = Set<String>()
        let boards = places.flatMap(\.boards).filter { seen.insert($0.id).inserted }
        let apiKey = UserDefaults.standard.string(forKey: Config.busTimeKeyDefaultsKey) ?? ""

        async let docks = capture { try await CitiBikeService.fetchDocks() }
        let results = await fetchArrivals(for: boards, apiKey: apiKey)
        let dockResult = await docks
        let now = Date()

        // Each board updates independently, so one failing API doesn't blank the others.
        for (boardID, result) in results {
            switch result {
            case .success(let arrivals):
                snapshot.arrivals[boardID] = arrivals
                snapshot.arrivalsFetchedAt[boardID] = now
                errors[boardID] = nil
            case .failure(let error):
                errors[boardID] = error.localizedDescription
            }
        }

        switch dockResult {
        case .success(let docks):
            for dock in docks { snapshot.docks[dock.id] = dock }
            snapshot.docksFetchedAt = now
            bikeError = nil
        case .failure(let error):
            bikeError = error.localizedDescription
        }

        SnapshotCache.save(snapshot)
        if Set(places.map(\.id)) == Set(Config.places.map(\.id)) { hasRefreshedAll = true }
    }

    func refreshAll() async {
        await refresh(Config.places)
    }

    /// Refreshes on a timer for as long as the calling task is alive. The first pass
    /// loads every tab, so all of them have saved data for offline use.
    func autoRefresh(_ place: Place) async {
        while !Task.isCancelled {
            await refresh(hasRefreshedAll ? [place] : Config.places)
            try? await Task.sleep(for: Config.autoRefreshInterval)
        }
    }

    func isStale(_ fetchedAt: Date?, now: Date = .now) -> Bool {
        guard let fetchedAt else { return true }
        return now.timeIntervalSince(fetchedAt) > Config.staleAfter
    }

    private nonisolated func fetchArrivals(for boards: [Board], apiKey: String) async -> [String: Result<[Arrival], Error>] {
        await withTaskGroup(of: [String: Result<[Arrival], Error>].self) { group in
            // All subway platforms come from one feed download.
            let subwayBoards = boards.filter { $0.kind == .subway }
            if !subwayBoards.isEmpty {
                group.addTask {
                    switch await capture({ try await SubwayService.fetchArrivals(for: subwayBoards) }) {
                    case .success(let byBoard):
                        return byBoard.mapValues { .success($0) }
                    case .failure(let error):
                        return Dictionary(uniqueKeysWithValues: subwayBoards.map { ($0.id, .failure(error)) })
                    }
                }
            }

            for board in boards where board.kind != .subway {
                group.addTask {
                    let result = await capture {
                        board.kind == .bus
                            ? try await BusTimeService.fetchArrivals(for: board, apiKey: apiKey)
                            : try await ShuttleService.fetchArrivals(for: board)
                    }
                    return [board.id: result]
                }
            }

            var merged: [String: Result<[Arrival], Error>] = [:]
            for await partial in group {
                merged.merge(partial) { _, new in new }
            }
            return merged
        }
    }
}

private func capture<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
    do { return .success(try await operation()) } catch { return .failure(error) }
}
