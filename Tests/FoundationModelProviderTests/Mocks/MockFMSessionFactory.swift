import Foundation
import AIProviderKit
@testable import FoundationModelProvider

// MARK: - MockFMSession

final class MockFMSession: FMSessionProtocol, @unchecked Sendable {

    var stubbedResponse: FMResponse = FMResponse(
        content: "",
        toolCalls: [],
        stopReason: .endTurn
    )
    var stubbedStreamDeltas: [FMStreamDelta] = []
    var stubbedError: (any Error)?

    private(set) var respondCallCount = 0
    private(set) var streamCallCount = 0

    func respond(to request: FMRequest) async throws -> FMResponse {
        respondCallCount += 1
        if let error = stubbedError { throw error }
        return stubbedResponse
    }

    func stream(_ request: FMRequest) -> AsyncThrowingStream<FMStreamDelta, any Error> {
        streamCallCount += 1
        let deltas = stubbedStreamDeltas
        let error = stubbedError
        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }
            for delta in deltas {
                continuation.yield(delta)
            }
            continuation.finish()
        }
    }
}

// MARK: - MockFMSessionFactory

final class MockFMSessionFactory: FMSessionFactory, @unchecked Sendable {

    /// The session instance returned by `makeSession(for:)`.
    var session: MockFMSession = MockFMSession()

    /// Error to throw from `makeSession(for:)` if non-nil.
    var stubbedError: (any Error)?

    private(set) var makeSessionCallCount = 0
    private(set) var lastRequest: FMRequest?

    func makeSession(for request: FMRequest) throws -> any FMSessionProtocol {
        makeSessionCallCount += 1
        lastRequest = request
        if let error = stubbedError { throw error }
        return session
    }
}
