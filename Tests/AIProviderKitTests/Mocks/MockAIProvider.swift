import AIProviderKit

final class MockAIProvider: AIProvider, @unchecked Sendable {

    let identifier = "mock"
    let capabilities: Set<AICapability> = [.text, .tools, .streaming, .systemPrompt]

    var stubbedResponse: AIResponse = MockData.response
    var stubbedError: (any Error)?
    var receivedRequests: [AIRequest] = []

    func send(_ request: AIRequest) async throws -> AIResponse {
        receivedRequests.append(request)
        if let error = stubbedError { throw error }
        return stubbedResponse
    }
}
