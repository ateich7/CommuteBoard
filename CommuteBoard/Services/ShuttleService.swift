import Foundation

/// Columbia shuttle arrivals from TripShot, the system behind columbia.tripshot.com.
///
/// GET /v2/p/routeSummary/{routeId}?day=YYYY-MM-DD returns every ride on the route that
/// day. Each ride has a stopStatus list; a stop that's still ahead is "Awaiting" (or
/// "Present" while the shuttle is there) with an expectedArrivalTime that TripShot
/// updates from the shuttle's GPS once the ride is live.
enum ShuttleService {
    static func fetchArrivals(for board: Board, on date: Date = .now) async throws -> [Arrival] {
        guard let routeID = board.lines.first else { return [] }

        var components = URLComponents(url: Config.tripShotBaseURL.appending(path: "v2/p/routeSummary/\(routeID)"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "day", value: serviceDay(for: date)),
            URLQueryItem(name: "withNavigation", value: "false"),
            URLQueryItem(name: "embedStops", value: "false"),
        ]
        let data = try await HTTP.get(components.url!)
        let summary = try JSONDecoder().decode(RouteSummary.self, from: data)

        return summary.rides.compactMap { ride -> Arrival? in
            guard let stop = ride.stopStatus.first(where: { $0.stopID == board.stopID && $0.isUpcoming }),
                  let time = stop.expectedArrivalTime.flatMap(parseDate)
            else { return nil }
            return Arrival(
                id: ride.rideId,
                kind: .shuttle,
                route: "CU",
                destination: board.destination ?? "Columbia shuttle",
                arrivalTime: time,
                detail: ride.liveDataAvailable == true ? "Live tracking" : "Scheduled"
            )
        }
        .sorted { ($0.arrivalTime ?? .distantFuture) < ($1.arrivalTime ?? .distantFuture) }
    }

    /// TripShot service days follow New York time, not the phone's time zone.
    private static func serviceDay(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    // MARK: Decoding

    private struct RouteSummary: Decodable {
        let rides: [Ride]
    }

    private struct Ride: Decodable {
        let rideId: String
        let liveDataAvailable: Bool?
        let stopStatus: [StopStatus]
    }

    /// Encoded as a one-key object naming the state, e.g. {"Awaiting": {"stopId": …}}.
    private struct StopStatus: Decodable {
        let state: String
        let stopID: String
        let expectedArrivalTime: String?

        var isUpcoming: Bool { state == "Awaiting" || state == "Present" }

        private struct StateKey: CodingKey {
            let stringValue: String
            let intValue: Int? = nil
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { return nil }
        }

        private struct Details: Decodable {
            let stopId: String
            let expectedArrivalTime: String?
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StateKey.self)
            guard let key = container.allKeys.first else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Empty stop status"))
            }
            let details = try container.decode(Details.self, forKey: key)
            state = key.stringValue
            stopID = details.stopId
            expectedArrivalTime = details.expectedArrivalTime
        }
    }
}
