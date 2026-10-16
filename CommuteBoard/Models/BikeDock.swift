import Foundation
import CoreLocation

/// Live status of one Citi Bike dock.
struct BikeDock: Identifiable, Codable, Hashable {
    let id: String
    let ebikes: Int
    let classicBikes: Int
    let openDocks: Int
    let disabledBikes: Int
    let disabledDocks: Int
    let isRenting: Bool
    let isReturning: Bool
    let lastReported: Date

    var capacity: Int { ebikes + classicBikes + openDocks + disabledBikes + disabledDocks }
    var totalBikes: Int { ebikes + classicBikes }

    var info: DockInfo? { Config.allDocks.first { $0.id == id } }
    var nickname: String { info?.nickname ?? "Citi Bike dock" }
    var officialName: String { info?.officialName ?? id }
    var coordinate: CLLocationCoordinate2D? { info?.coordinate }

    var status: Status {
        if !isRenting && !isReturning { return .offline }
        if openDocks == 0 { return .full }
        if totalBikes == 0 { return .empty }
        if totalBikes <= 3 { return .low }
        return .available
    }

    enum Status {
        case available, low, empty, full, offline

        var label: String {
            switch self {
            case .available: "Bikes available"
            case .low: "Running low"
            case .empty: "No bikes"
            case .full: "Dock full"
            case .offline: "Out of service"
            }
        }

        /// Short label for the badge on the list row; nil when there's nothing to warn about.
        var badge: String? {
            switch self {
            case .available: nil
            case .low: "LOW"
            case .empty: "EMPTY"
            case .full: "FULL"
            case .offline: "OFFLINE"
            }
        }
    }
}
