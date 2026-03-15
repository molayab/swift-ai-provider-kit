import Foundation

/// Thrown by `URLSessionHTTPClient.stream` when the server responds with a non-2xx status.
/// Providers catch this and map it to `AIError` via their `validateStatus` helper.
struct HTTPStreamError: Error {
    let statusCode: Int
    let body: Data
}

/// Internal HTTP abstraction, enabling injection of mock clients in tests.
protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
    func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, any Error>
}

struct HTTPRequest: Sendable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data?
}

struct HTTPResponse: Sendable {
    let statusCode: Int
    let body: Data
}
