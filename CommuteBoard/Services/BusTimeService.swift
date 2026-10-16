import Foundation

/// M4 arrivals from MTA Bus Time (SIRI StopMonitoring). One request per stop.
enum BusTimeService {
    enum BusTimeError: LocalizedError {
        case missingAPIKey
        case api(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: "Add your MTA Bus Time API key in Settings."
            case .api(let message): "Bus Time: \(message)"
            }
        }
    }

    static func fetchArrivals(for board: Board, apiKey: String) async throws -> [Arrival] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw BusTimeError.missingAPIKey }

        let line = board.lines.first ?? "M4"
        var components = URLComponents(url: Config.busTimeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "MonitoringRef", value: board.stopID),
            URLQueryItem(name: "LineRef", value: "MTA NYCT_\(line)"),
        ]
        let data = try await HTTP.get(components.url!)
        let response = try decoder.decode(SiriResponse.self, from: data)
        let delivery = response.siri.serviceDelivery

        if let message = delivery.stopMonitoringDelivery?.first?.errorCondition?.description
            ?? delivery.vehicleMonitoringDelivery?.first?.errorCondition?.description {
            throw BusTimeError.api(message)
        }

        let visits = delivery.stopMonitoringDelivery?.first?.monitoredStopVisit ?? []
        return visits.map { visit in
            let journey = visit.monitoredVehicleJourney
            let call = journey.monitoredCall
            let (destination, isLimited) = prettify(journey.destinationName ?? "")
            let arrivalTime = call?.expectedArrivalTime.flatMap(parseDate)
            return Arrival(
                id: journey.framedVehicleJourneyRef?.datedVehicleJourneyRef ?? journey.vehicleRef ?? UUID().uuidString,
                kind: .bus,
                route: journey.publishedLineName ?? line,
                destination: destination,
                arrivalTime: arrivalTime,
                // The countdown already says how far away it is; distance is only
                // useful for buses that don't have a predicted time yet.
                detail: arrivalTime == nil ? describeDistance(call?.extensions?.distances) : nil,
                isLimited: isLimited
            )
        }
        .sorted { ($0.arrivalTime ?? .distantFuture) < ($1.arrivalTime ?? .distantFuture) }
    }

    // MARK: Formatting

    private static func describeDistance(_ distances: SiriResponse.Distances?) -> String? {
        guard let distances else { return nil }
        var parts: [String] = []
        if let presentable = distances.presentableDistance { parts.append(presentable) }
        // PresentableDistance is sometimes already "1 stop away"; don't repeat it.
        if let stops = distances.stopsFromCall, stops > 0, !parts.contains(where: { $0.contains("stop") }) { parts.append("\(stops) stop\(stops == 1 ? "" : "s")") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Headsigns look like "LTD WASH HTS CABRINI  via MADSN via BWAY".
    /// Keep the part before "via", expand abbreviations, and flag limited-stop buses.
    static func prettify(_ headsign: String) -> (String, isLimited: Bool) {
        let main = headsign.components(separatedBy: " via ").first ?? headsign
        var words = main.split(separator: " ").map(String.init)
        let isLimited = words.first == "LTD" || words.first == "LIMITED"
        if isLimited { words.removeFirst() }

        let expansions = [
            "WSHNGTN": "Washington", "WASH": "Washington", "HTS": "Hts",
            "CLOISTRS": "Cloisters", "MIDTWN": "Midtown", "ST": "St", "AV": "Av",
        ]
        let pretty = words
            .map { expansions[$0] ?? $0.capitalized }
            .joined(separator: " ")
        return (pretty.isEmpty ? "M4" : pretty, isLimited)
    }

    // MARK: Decoding

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // SIRI uses PascalCase keys ("MonitoredStopVisit"); lowercase the first letter.
        decoder.keyDecodingStrategy = .custom { path in
            let key = path.last!.stringValue
            return AnyCodingKey(key.prefix(1).lowercased() + key.dropFirst())
        }
        return decoder
    }()

    private static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

/// Just the parts of the SIRI response this app uses.
private struct SiriResponse: Decodable {
    let siri: Siri

    struct Siri: Decodable {
        let serviceDelivery: ServiceDelivery
    }

    struct ServiceDelivery: Decodable {
        let stopMonitoringDelivery: [Delivery]?
        let vehicleMonitoringDelivery: [Delivery]?
    }

    struct Delivery: Decodable {
        let monitoredStopVisit: [Visit]?
        let errorCondition: ErrorCondition?
    }

    struct ErrorCondition: Decodable {
        let description: String?
    }

    struct Visit: Decodable {
        let monitoredVehicleJourney: Journey
    }

    struct Journey: Decodable {
        let publishedLineName: String?
        let destinationName: String?
        let vehicleRef: String?
        let framedVehicleJourneyRef: JourneyRef?
        let monitoredCall: Call?
    }

    struct JourneyRef: Decodable {
        let datedVehicleJourneyRef: String?
    }

    struct Call: Decodable {
        let expectedArrivalTime: String?
        let extensions: Extensions?
    }

    struct Extensions: Decodable {
        let distances: Distances?
    }

    struct Distances: Decodable {
        let presentableDistance: String?
        let stopsFromCall: Int?
    }
}
