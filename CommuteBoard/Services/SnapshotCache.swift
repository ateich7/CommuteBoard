import Foundation

/// Persists the latest CommuteSnapshot as JSON in Application Support.
enum SnapshotCache {
    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "commute-snapshot-v2.json")
    }

    static func load() -> CommuteSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(CommuteSnapshot.self, from: data)
    }

    static func save(_ snapshot: CommuteSnapshot) {
        do {
            try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
        } catch {
            print("SnapshotCache: failed to save – \(error)")
        }
    }
}
