@testable import ClaudeProvider
import Foundation

final class MockHTTPClient: HTTPClient, @unchecked Sendable {

    var stubbedResponse = HTTPResponse(statusCode: 200, body: Data())
    var stubbedError: (any Error)?
    var stubbedStreamData: [Data] = []
    var stubbedStreamError: (any Error)?
    private(set) var receivedRequests: [HTTPRequest] = []

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        receivedRequests.append(request)
        if let error = stubbedError { throw error }
        return stubbedResponse
    }

    func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, any Error> {
        receivedRequests.append(request)
        let data = stubbedStreamData
        let error = stubbedStreamError
        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }
            for chunk in data { continuation.yield(chunk) }
            continuation.finish()
        }
    }
}
