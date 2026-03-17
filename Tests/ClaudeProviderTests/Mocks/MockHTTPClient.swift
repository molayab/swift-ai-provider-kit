@testable import ClaudeProvider
import Foundation

/// Test double for `HTTPClient`.
///
/// Marked `@unchecked Sendable` because its mutable state is accessed in a strictly
/// sequential manner within each test: all `stubbed*` properties are written once
/// during test setup (before any async call begins), `send`/`stream` are invoked via
/// `await` (establishing a happens-before edge), and `receivedRequests` is inspected
/// only after that `await` returns. This includes `stubbedResponseQueue`, whose
/// `removeFirst()` mutation inside `send(_:)` is safe because each page fetch
/// completes before the next begins — there is no concurrent access to the queue.
/// Each test owns its own `MockHTTPClient` instance, so no two concurrent contexts
/// ever access the same object simultaneously.
/// Violating this invariant (e.g. sharing the mock across concurrent tests) would
/// reintroduce the data race — do not do this.
final class MockHTTPClient: HTTPClient, @unchecked Sendable {

    var stubbedResponse = HTTPResponse(statusCode: 200, body: Data())
    /// When non-empty, `send` pops responses from the front of the queue in order.
    /// Falls back to `stubbedResponse` once the queue is exhausted.
    var stubbedResponseQueue: [HTTPResponse] = []
    var stubbedError: (any Error)?
    var stubbedStreamData: [Data] = []
    var stubbedStreamError: (any Error)?
    private(set) var receivedRequests: [HTTPRequest] = []

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        receivedRequests.append(request)
        if let error = stubbedError { throw error }
        if !stubbedResponseQueue.isEmpty { return stubbedResponseQueue.removeFirst() }
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
