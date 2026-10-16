import Foundation

/// One predicted train or bus arrival at my stop.
struct Arrival: Identifiable, Codable, Hashable {
    let id: String
    let kind: Board.Kind
    /// Badge text: "1", "2", "3", "M4", or "CU" for Columbia shuttles.
    let route: String
    let destination: String
    /// Absolute time, so cached arrivals can keep counting down while offline.
    /// Buses that haven't left the terminal sometimes only report a distance.
    let arrivalTime: Date?
    /// Extra context, e.g. "Scheduled" for shuttles or "0.5 miles away" for an untimed bus.
    let detail: String?
    var isLimited: Bool = false

    func minutesText(now: Date) -> String {
        guard let arrivalTime else { return "—" }
        let seconds = arrivalTime.timeIntervalSince(now)
        if seconds < 30 { return "Now" }
        return "\(max(1, Int(seconds / 60))) min"
    }

    /// Bare number for compact "then 9, 15" lists.
    func minutes(now: Date) -> Int? {
        arrivalTime.map { max(0, Int($0.timeIntervalSince(now) / 60)) }
    }
}

extension Array where Element == Arrival {
    /// Drops arrivals that have already happened. Arrivals with no time are only
    /// trusted while the data is fresh, since there's nothing to count down from.
    func upcoming(now: Date, fetchedAt: Date?) -> [Arrival] {
        let isFresh = fetchedAt.map { now.timeIntervalSince($0) < Config.staleAfter } ?? false
        return filter { arrival in
            if let time = arrival.arrivalTime { return time.timeIntervalSince(now) > -30 }
            return isFresh
        }
    }
}
