import AIProviderKit

/// A mock `AIProvider` that returns a predefined sequence of responses.
/// Useful for testing multi-turn flows such as automatic tool execution.
final class SequentialMockProvider: AIProvider, @unchecked Sendable {

    let identifier = "sequential-mock"
    let capabilities: Set<AICapability> = [.text, .tools]

    private(set) var receivedRequests: [AIRequest] = []
    private var responses: [AIResponse]
    private var index = 0

    init(responses: [AIResponse]) {
        self.responses = responses
    }

    // swiftlint:disable:next async_without_await unneeded_throws_rethrows
    func send(_ request: AIRequest) async throws -> AIResponse {
        receivedRequests.append(request)
        let response = responses[min(index, responses.count - 1)]
        index += 1
        return response
    }
}
