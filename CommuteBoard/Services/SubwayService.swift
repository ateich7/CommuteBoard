import Foundation

/// Subway arrivals from the MTA's GTFS-Realtime feed. One download covers every
/// 1/2/3 platform in the app, so all subway boards are fetched together.
enum SubwayService {
    /// Returns arrivals keyed by Board.id.
    static func fetchArrivals(for boards: [Board]) async throws -> [String: [Arrival]] {
        let data = try await HTTP.get(Config.subwayFeedURL)
        return try GTFSRealtimeParser.arrivals(in: data, for: boards)
    }
}

/// Pulls arrivals for specific platforms out of a GTFS-Realtime FeedMessage.
///
/// Field numbers come from gtfs-realtime.proto:
///   FeedMessage    { 2: entity (repeated FeedEntity) }
///   FeedEntity     { 3: trip_update (TripUpdate) }
///   TripUpdate     { 1: trip (TripDescriptor), 2: stop_time_update (repeated) }
///   TripDescriptor { 1: trip_id, 5: route_id }
///   StopTimeUpdate { 2: arrival, 3: departure, 4: stop_id }
///   StopTimeEvent  { 2: time (POSIX seconds) }
enum GTFSRealtimeParser {
    static func arrivals(in data: Data, for boards: [Board]) throws -> [String: [Arrival]] {
        var result = Dictionary(uniqueKeysWithValues: boards.map { ($0.id, [Arrival]()) })
        var feed = ProtobufReader(data)

        while let (field, value) = try feed.next() {
            guard field == 2, case .bytes(let entityBytes) = value else { continue }
            var entity = ProtobufReader(entityBytes)
            while let (field, value) = try entity.next() {
                guard field == 3, case .bytes(let tripUpdate) = value else { continue }
                let trip = try parseTripUpdate(tripUpdate)
                for board in boards {
                    if let arrival = trip.arrival(at: board) {
                        result[board.id, default: []].append(arrival)
                    }
                }
            }
        }

        return result.mapValues { arrivals in
            arrivals.sorted { ($0.arrivalTime ?? .distantFuture) < ($1.arrivalTime ?? .distantFuture) }
        }
    }

    private struct StopTime {
        var stopID = ""
        var time: Date?
    }

    private struct Trip {
        var tripID = ""
        var routeID = ""
        var stopTimes: [StopTime] = []

        func arrival(at board: Board) -> Arrival? {
            guard board.lines.contains(routeID),
                  let time = stopTimes.first(where: { $0.stopID == board.stopID })?.time
            else { return nil }

            let terminalID = String(stopTimes.last?.stopID.dropLast() ?? "")
            return Arrival(
                id: tripID,
                kind: .subway,
                route: routeID,
                destination: SubwayStations.names[terminalID] ?? (board.stopID.hasSuffix("N") ? "Uptown" : "Downtown"),
                arrivalTime: time,
                detail: nil
            )
        }
    }

    private static func parseTripUpdate(_ bytes: ArraySlice<UInt8>) throws -> Trip {
        var trip = Trip()
        var reader = ProtobufReader(bytes)
        while let (field, value) = try reader.next() {
            guard case .bytes(let nested) = value else { continue }
            switch field {
            case 1:
                var descriptor = ProtobufReader(nested)
                while let (field, value) = try descriptor.next() {
                    if field == 1 { trip.tripID = value.string ?? "" }
                    if field == 5 { trip.routeID = value.string ?? "" }
                }
            case 2:
                trip.stopTimes.append(try parseStopTime(nested))
            default:
                break
            }
        }
        return trip
    }

    private static func parseStopTime(_ bytes: ArraySlice<UInt8>) throws -> StopTime {
        var stopTime = StopTime()
        var arrival: Date?
        var departure: Date?

        var reader = ProtobufReader(bytes)
        while let (field, value) = try reader.next() {
            switch (field, value) {
            case (2, .bytes(let event)): arrival = try parseEventTime(event)
            case (3, .bytes(let event)): departure = try parseEventTime(event)
            case (4, _): stopTime.stopID = value.string ?? ""
            default: break
            }
        }
        // The first stop of a trip often only has a departure time.
        stopTime.time = arrival ?? departure
        return stopTime
    }

    private static func parseEventTime(_ bytes: ArraySlice<UInt8>) throws -> Date? {
        var reader = ProtobufReader(bytes)
        while let (field, value) = try reader.next() {
            if field == 2, case .varint(let seconds) = value {
                return Date(timeIntervalSince1970: TimeInterval(seconds))
            }
        }
        return nil
    }
}
