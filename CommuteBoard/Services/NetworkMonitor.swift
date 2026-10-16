import Foundation
import Network
import Observation

/// Publishes whether the device currently has a network connection.
@Observable
final class NetworkMonitor {
    private(set) var isConnected = true

    private let monitor = NWPathMonitor()

    init() {
        #if DEBUG
        // Launch argument for demoing offline mode: -simulateOffline YES
        let simulateOffline = UserDefaults.standard.bool(forKey: "simulateOffline")
        #else
        let simulateOffline = false
        #endif
        isConnected = !simulateOffline

        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied && !simulateOffline
            DispatchQueue.main.async { self?.isConnected = connected }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    deinit {
        monitor.cancel()
    }
}
