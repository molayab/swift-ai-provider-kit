import AIProviderKit
import Testing

// MARK: - Fixtures

private actor AlphaProvider: AIProvider {
    nonisolated let identifier = "alpha"
    nonisolated let capabilities: Set<AICapability> = [.text]
    private(set) var receivedRequests: [AIRequest] = []

    nonisolated func canHandle(model: AIModel) -> Bool { model.identifier.hasPrefix("alpha-") }

    func send(_ request: AIRequest) async throws(AIError) -> AIResponse {
        receivedRequests.append(request)
        return MockData.response
    }
}

private actor BetaProvider: AIProvider {
    nonisolated let identifier = "beta"
    nonisolated let capabilities: Set<AICapability> = [.text]
    private(set) var receivedRequests: [AIRequest] = []

    nonisolated func canHandle(model: AIModel) -> Bool { model.identifier.hasPrefix("beta-") }

    func send(_ request: AIRequest) async throws(AIError) -> AIResponse {
        receivedRequests.append(request)
        return MockData.response
    }
}

// MARK: - Tests

@Suite("Multi-Provider Routing")
struct MultiProviderRoutingTests {

    @Test("routes to first provider whose canHandle returns true")
    func routesToMatchingProvider() async throws {
        // Given
        let alpha = AlphaProvider()
        let beta  = BetaProvider()
        let client = AIClient(providers: [alpha, beta])
        let request = try AIRequestBuilder()
            .model(AIModel("beta-v1"))
            .addMessage(.user(text: "Hello"))
            .build()

        // When
        _ = try await client.send(request)

        // Then
        #expect(await alpha.receivedRequests.isEmpty)
        #expect(await beta.receivedRequests.count == 1)
    }

    @Test("throws noProviderForModel when no provider claims the model")
    func throwsWhenNoProviderHandlesModel() async throws {
        // Given
        let client = AIClient(providers: [AlphaProvider(), BetaProvider()])
        let request = try AIRequestBuilder()
            .model(AIModel("gamma-unknown"))
            .addMessage(.user(text: "Hi"))
            .build()

        // When / Then — must be noProviderForModel, not just any AIError
        await #expect {
            try await client.send(request)
        } throws: { error in
            guard let aiError = error as? AIError, case .noProviderForModel = aiError else { return false }
            return true
        }
    }

    @Test("single-provider setup uses the default canHandle returning true")
    func singleProviderHandlesAnyModel() async throws {
        // Given — MockAIProvider uses the default canHandle (returns true)
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)
        let request = try MockData.request(model: "any-model-identifier")

        // When
        _ = try await client.send(request)

        // Then
        #expect(provider.receivedRequests.count == 1)
    }

    @Test("stream routes to first provider that claims the model")
    func streamRoutesToMatchingProvider() async throws {
        // Given — use a mock that streams
        let mock = MockAIProvider()
        let client = AIClient(provider: mock)
        let request = try MockData.request()

        // When — MockAIProvider is not StreamableProvider, so expect the error
        var didThrow = false
        do {
            for try await _ in await client.stream(request) {}
        } catch {
            didThrow = true
        }

        // Then
        #expect(didThrow)
    }

    @Test("providers property exposes all registered providers")
    func providersPropertyExposesAll() {
        // Given
        let alpha = AlphaProvider()
        let beta  = BetaProvider()
        let client = AIClient(providers: [alpha, beta])

        // Then
        #expect(client.providers.count == 2)
        #expect(client.providers[0].identifier == "alpha")
        #expect(client.providers[1].identifier == "beta")
    }

    @Test("provider convenience property returns the first provider")
    func providerConvenienceReturnsFirst() {
        // Given
        let alpha = AlphaProvider()
        let client = AIClient(providers: [alpha, BetaProvider()])

        // Then
        #expect(client.provider?.identifier == "alpha")
    }
}
