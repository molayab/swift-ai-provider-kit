import Foundation

/// Thrown by `URLSessionHTTPClient.stream` when the server responds with a non-2xx status.
/// Providers catch this and map it to `AIError` via their `validateStatus` helper.
public struct HTTPStreamError: Error, Sendable {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

/// HTTP abstraction enabling injection of alternative backends per platform or test context.
///
/// Providers accept `any HTTPClient` at initialisation time — swap the concrete type to target
/// a different platform (e.g. an `AsyncHTTPClient`-backed implementation on Linux) or to stub
/// the network layer in unit tests via a mock conformer.
///
/// The default Apple-platform implementation is `URLSessionHTTPClient`.
public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
    func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, any Error>
}

public struct HTTPRequest: Sendable {
    public let method: String
    public let url: URL
    public let headers: [String: String]
    public let body: Data?

    public init(method: String, url: URL, headers: [String: String], body: Data?) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}
