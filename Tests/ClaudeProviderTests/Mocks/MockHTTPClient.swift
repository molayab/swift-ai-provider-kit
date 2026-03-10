import Foundation
@testable import ClaudeProvider

final class MockHTTPClient: HTTPClient, @unchecked Sendable {

    var stubbedResponse: HTTPResponse = HTTPResponse(statusCode: 200, body: Data())
    var stubbedError: (any Error)?
    var stubbedStreamData: [Data] = []
    private(set) var receivedRequests: [HTTPRequest] = []

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        receivedRequests.append(request)
        if let error = stubbedError { throw error }
        return stubbedResponse
    }

    func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, any Error> {
        receivedRequests.append(request)
        let data = stubbedStreamData
        return AsyncThrowingStream { continuation in
            for chunk in data { continuation.yield(chunk) }
            continuation.finish()
        }
    }
}
