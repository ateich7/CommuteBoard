import Foundation
import CoreLocation

/// Everything specific to "my" commute lives here: one Place per tab, each with its
/// own stops and docks. IDs were looked up from the MTA static GTFS feeds, Citi Bike's
/// station_information.json, and Columbia's TripShot route data.
enum Config {

    // MARK: Places (one per tab)

    static let places: [Place] = [home, main, cbs]

    static let home = Place(
        id: "home",
        name: "Home",
        systemImage: "house.fill",
        boards: [
            .subway(title: "Downtown 2 · 3", direction: "Downtown", station: "110 St–Malcolm X Plaza", stopID: "227S",
                    routes: ["2", "3"], coordinate: .init(latitude: 40.799075, longitude: -73.951822)),
            .bus(title: "M4 Uptown", direction: "Uptown", stopName: "110th St (Central Park N) & Malcolm X Blvd", stopID: "400224",
                 line: "M4", coordinate: .init(latitude: 40.798395, longitude: -73.952601)),
        ],
        docks: [
            DockInfo(id: "0e003543-3656-448f-8a93-029d265f2e26", nickname: "Malcolm X & 110th",
                     officialName: "Lenox Ave & W 111 St", coordinate: .init(latitude: 40.7987859, longitude: -73.9523)),
            DockInfo(id: "66de2625-0aca-11e7-82f6-3863bb44ef7c", nickname: "Adam Clayton & 110th",
                     officialName: "Central Park North & Adam Clayton Powell Blvd", coordinate: .init(latitude: 40.799484, longitude: -73.955613)),
        ]
    )

    static let main = Place(
        id: "main",
        name: "Main",
        systemImage: "building.columns.fill",
        boards: [
            .shuttle(title: "M'ville to CBS", direction: "To CBS", stopName: "Broadway & W 116 St", stopID: "2d8c1cb3-1831-4c75-8047-67e5f351d487",
                     routeID: mvilleRouteID, destination: "Manhattanville", coordinate: .init(latitude: 40.807792, longitude: -73.963844)),
            .subway(title: "Uptown 1", direction: "Uptown", station: "116 St–Columbia University", stopID: "117N",
                    routes: ["1"], coordinate: .init(latitude: 40.807722, longitude: -73.964110)),
            .subway(title: "Downtown 1", direction: "Downtown", station: "116 St–Columbia University", stopID: "117S",
                    routes: ["1"], coordinate: .init(latitude: 40.807722, longitude: -73.964110)),
            .bus(title: "M4 Uptown", direction: "Uptown", stopName: "Broadway & W 116 St", stopID: "403122",
                 line: "M4", coordinate: .init(latitude: 40.807895, longitude: -73.963813)),
            .bus(title: "M4 Downtown", direction: "Downtown", stopName: "Broadway & W 116 St", stopID: "403147",
                 line: "M4", coordinate: .init(latitude: 40.807957, longitude: -73.964220)),
        ],
        docks: [
            DockInfo(id: "8e631be4-1e0c-4627-a261-18f0003d0ba2", nickname: "116th & Broadway",
                     officialName: "W 116 St & Broadway", coordinate: .init(latitude: 40.8082, longitude: -73.9641)),
            DockInfo(id: "5b4a90b8-426d-4a40-a7ca-87e51d690883", nickname: "113th & Broadway",
                     officialName: "W 113 St & Broadway", coordinate: .init(latitude: 40.805973, longitude: -73.964928)),
            DockInfo(id: "7efcb97f-6c8f-4445-86a9-3f758a822f17", nickname: "116th & Amsterdam",
                     officialName: "W 116 St & Amsterdam Ave", coordinate: .init(latitude: 40.8067581, longitude: -73.9607082)),
            DockInfo(id: "bb32aad7-8308-4ff8-b073-d5b518ffdd09", nickname: "120th & Claremont",
                     officialName: "W 120 St & Claremont Ave", coordinate: .init(latitude: 40.8109494, longitude: -73.9634)),
        ]
    )

    static let cbs = Place(
        id: "cbs",
        name: "CBS",
        systemImage: "briefcase.fill",
        boards: [
            .subway(title: "Downtown 1", direction: "Downtown", station: "125 St", stopID: "116S",
                    routes: ["1"], coordinate: .init(latitude: 40.815581, longitude: -73.958372)),
            .bus(title: "M4 Downtown", direction: "Downtown", stopName: "Broadway & Tiemann Pl (W 127th St)", stopID: "403142",
                 line: "M4", coordinate: .init(latitude: 40.815025, longitude: -73.959043)),
        ],
        docks: [
            DockInfo(id: "26599393-b967-44a6-a998-cb72ca53cd9e", nickname: "Broadway & 131st",
                     officialName: "Broadway & W 131 St", coordinate: .init(latitude: 40.817555, longitude: -73.957163)),
            DockInfo(id: "bc5235a5-7f10-4a27-806e-9c25fa700959", nickname: "Broadway & Moylan Pl",
                     officialName: "Broadway & Moylan Pl", coordinate: .init(latitude: 40.8143256, longitude: -73.9590255)),
            DockInfo(id: "eab2749b-2f79-4797-a0a6-0579b27e6929", nickname: "12th Ave & 125th",
                     officialName: "12 Ave & W 125 St", coordinate: .init(latitude: 40.818299, longitude: -73.960405)),
        ]
    )

    static var allBoards: [Board] { places.flatMap(\.boards) }
    static var allDocks: [DockInfo] { places.flatMap(\.docks) }

    // MARK: Subway — MTA GTFS-Realtime (no API key required)

    /// Feed that covers the 1/2/3/4/5/6/7/S lines. Protocol Buffers, not JSON.
    static let subwayFeedURL = URL(string: "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs")!

    // MARK: Bus — MTA Bus Time SIRI API (free key: https://register.developer.obanyc.com)

    static let busTimeURL = URL(string: "https://bustime.mta.info/api/siri/stop-monitoring.json")!
    static let busTimeKeyDefaultsKey = "busTimeAPIKey"

    // MARK: Columbia shuttles — TripShot public tracker (no key; same data as columbia.tripshot.com)

    static let tripShotBaseURL = URL(string: "https://columbia.tripshot.com")!
    static let mvilleRouteID = "90668f3a-74ac-4363-9ef0-8e0bd45f105f"

    // MARK: Citi Bike — GBFS (no API key required)

    static let citiBikeStatusURL = URL(string: "https://gbfs.citibikenyc.com/gbfs/en/station_status.json")!

    // MARK: Behavior

    static let autoRefreshInterval: Duration = .seconds(30)
    /// After this long without a successful fetch, data is shown as stale.
    static let staleAfter: TimeInterval = 3 * 60
}

/// A location in the app — one tab.
struct Place: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
    let boards: [Board]
    let docks: [DockInfo]

    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// One list of arrivals: a subway platform, a bus stop in one direction, or a shuttle stop.
struct Board: Identifiable, Hashable {
    enum Kind: String, Codable {
        case subway, bus, shuttle

        var label: String {
            switch self {
            case .subway: "Train"
            case .bus: "Bus"
            case .shuttle: "Shuttle"
            }
        }

        var systemImage: String {
            switch self {
            case .subway: "tram.fill.tunnel"
            case .bus: "bus.fill"
            case .shuttle: "bus.doubledecker.fill"
            }
        }
    }

    let kind: Kind
    let title: String
    /// What the card says next to the badge: "Uptown", "Downtown", "To CBS".
    let direction: String
    let stopName: String
    let stopID: String
    let coordinate: CLLocationCoordinate2D
    /// Subway: the routes to show ("2", "3"). Bus: the line ("M4"). Shuttle: the TripShot route ID.
    let lines: [String]
    /// Shuttle only — where it's headed, since TripShot loops have no headsign.
    var destination: String?

    var id: String { "\(kind.rawValue)-\(stopID)" }

    /// Badge for the card when nothing is coming: the line, or "CU" for the shuttle.
    var badgeText: String { kind == .shuttle ? "CU" : (lines.first ?? "") }

    static func subway(title: String, direction: String, station: String, stopID: String, routes: [String], coordinate: CLLocationCoordinate2D) -> Board {
        Board(kind: .subway, title: title, direction: direction, stopName: station, stopID: stopID, coordinate: coordinate, lines: routes)
    }

    static func bus(title: String, direction: String, stopName: String, stopID: String, line: String, coordinate: CLLocationCoordinate2D) -> Board {
        Board(kind: .bus, title: title, direction: direction, stopName: stopName, stopID: stopID, coordinate: coordinate, lines: [line])
    }

    static func shuttle(title: String, direction: String, stopName: String, stopID: String, routeID: String, destination: String, coordinate: CLLocationCoordinate2D) -> Board {
        Board(kind: .shuttle, title: title, direction: direction, stopName: stopName, stopID: stopID, coordinate: coordinate, lines: [routeID], destination: destination)
    }

    static func == (lhs: Board, rhs: Board) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct DockInfo: Identifiable {
    let id: String
    let nickname: String
    let officialName: String
    let coordinate: CLLocationCoordinate2D
}
