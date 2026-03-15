import Foundation

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
