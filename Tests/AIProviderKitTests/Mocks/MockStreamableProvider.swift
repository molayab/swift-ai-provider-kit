import AIProviderKit

final class MockStreamableProvider: StreamableProvider, @unchecked Sendable {

    let identifier = "mock-stream"
    let capabilities: Set<AICapability> = [.text, .tools, .streaming, .systemPrompt]

    var stubbedEvents: [AIStreamEvent] = []
    var stubbedError: (any Error)?
    var receivedRequests: [AIRequest] = []

    func send(_ request: AIRequest) async throws(AIError) -> AIResponse {
        receivedRequests.append(request)
        return MockData.response
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        receivedRequests.append(request)
        let events = stubbedEvents
        let error = stubbedError
        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }
}
