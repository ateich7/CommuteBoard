import Foundation

/// The last good data from every source. Saved to disk after each refresh and
/// loaded on launch, which is what makes the app usable with no network.
struct CommuteSnapshot: Codable {
    /// Keyed by Board.id.
    var arrivals: [String: [Arrival]] = [:]
    var arrivalsFetchedAt: [String: Date] = [:]

    /// Keyed by Citi Bike station ID.
    var docks: [String: BikeDock] = [:]
    var docksFetchedAt: Date?

    func arrivals(for board: Board) -> [Arrival] { arrivals[board.id] ?? [] }
    func fetchedAt(for board: Board) -> Date? { arrivalsFetchedAt[board.id] }

    /// The oldest successful fetch among a place's sources, used for the offline banner.
    func oldestFetch(for place: Place) -> Date? {
        (place.boards.map { arrivalsFetchedAt[$0.id] } + [docksFetchedAt]).compactMap { $0 }.min()
    }

    /// The most recent successful fetch among a place's sources, for the page's "Updated" line.
    func latestFetch(for place: Place) -> Date? {
        (place.boards.map { arrivalsFetchedAt[$0.id] } + [docksFetchedAt]).compactMap { $0 }.max()
    }

    func hasData(for place: Place) -> Bool {
        docksFetchedAt != nil || place.boards.contains { arrivalsFetchedAt[$0.id] != nil }
    }
}
