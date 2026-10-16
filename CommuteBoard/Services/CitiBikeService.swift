import Foundation

/// Live bike/dock counts for every dock in the app from Citi Bike's GBFS feed.
enum CitiBikeService {
    static func fetchDocks() async throws -> [BikeDock] {
        let data = try await HTTP.get(Config.citiBikeStatusURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let feed = try decoder.decode(StationStatusFeed.self, from: data)

        let byID = Dictionary(feed.data.stations.map { ($0.stationId, $0) }, uniquingKeysWith: { first, _ in first })
        return Config.allDocks.compactMap { info in
            guard let station = byID[info.id] else { return nil }
            let ebikes = station.numEbikesAvailable ?? 0
            return BikeDock(
                id: info.id,
                ebikes: ebikes,
                classicBikes: max(0, station.numBikesAvailable - ebikes),
                openDocks: station.numDocksAvailable,
                disabledBikes: station.numBikesDisabled ?? 0,
                disabledDocks: station.numDocksDisabled ?? 0,
                isRenting: station.isRenting == 1,
                isReturning: station.isReturning == 1,
                lastReported: Date(timeIntervalSince1970: TimeInterval(station.lastReported))
            )
        }
    }

    private struct StationStatusFeed: Decodable {
        let data: Stations

        struct Stations: Decodable {
            let stations: [Station]
        }

        struct Station: Decodable {
            let stationId: String
            let numBikesAvailable: Int
            let numEbikesAvailable: Int?
            let numBikesDisabled: Int?
            let numDocksAvailable: Int
            let numDocksDisabled: Int?
            let isRenting: Int
            let isReturning: Int
            let lastReported: Int
        }
    }
}
