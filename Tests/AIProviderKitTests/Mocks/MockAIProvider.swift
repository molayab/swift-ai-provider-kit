import AIProviderKit

final class MockAIProvider: AIProvider, @unchecked Sendable {

    let identifier = "mock"
    let capabilities: Set<AICapability> = [.text, .tools, .streaming, .systemPrompt]

    var stubbedResponse: AIResponse = MockData.response
    var stubbedError: (any Error)?
    var receivedRequests: [AIRequest] = []

    // swiftlint:disable:next async_without_await
    func send(_ request: AIRequest) async throws -> AIResponse {
        receivedRequests.append(request)
        if let error = stubbedError { throw error }
        return stubbedResponse
    }
}
