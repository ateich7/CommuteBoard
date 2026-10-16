import Foundation

enum HTTP {
    struct StatusError: LocalizedError {
        let code: Int
        var errorDescription: String? { "Server returned HTTP \(code)." }
    }

    /// Short timeouts and no URL cache: stale transit data from URLCache would be worse
    /// than our own cache, which knows how old it is.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    static func get(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw StatusError(code: http.statusCode)
        }
        return data
    }
}
