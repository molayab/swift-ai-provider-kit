import Testing
import AIProviderKit

@Suite("AIClient")
struct AIClientTests {

    @Test("forwards request to provider and returns response")
    func sendForwardsRequest() async throws {
        // GIVEN
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)
        let request = try MockData.request()

        // WHEN
        let response = try await client.send(request)

        // THEN
        #expect(provider.receivedRequests.count == 1)
        #expect(response.id == MockData.response.id)
    }

    @Test("propagates provider errors")
    func sendPropagatesErrors() async throws {
        // GIVEN
        let provider = MockAIProvider()
        provider.stubbedError = AIError.invalidResponse(statusCode: 500, body: nil)
        let client = AIClient(provider: provider)
        let request = try MockData.request()

        // WHEN / THEN
        await #expect(throws: AIError.self) {
            try await client.send(request)
        }
    }

    @Test("executes tool calls automatically before returning final response")
    func sendExecutesToolsAutomatically() async throws {
        // GIVEN
        let provider = SequentialMockProvider(responses: [
            MockData.toolUseResponse,
            MockData.response
        ])
        let client = AIClient(provider: provider)
        await client.toolRegistry.register(MockData.weatherTool)
        let request = try MockData.request()

        // WHEN
        let response = try await client.send(request)

        // THEN
        #expect(response.id == MockData.response.id)
        #expect(provider.receivedRequests.count == 2)
        let followUp = provider.receivedRequests[1]
        let hasToolResult = followUp.messages.contains {
            $0.content.contains { if case .toolResult = $0 { return true }; return false }
        }
        #expect(hasToolResult)
    }

    @Test("stream throws providerUnsupported when provider lacks streaming capability")
    func streamThrowsWhenUnsupported() async throws {
        // GIVEN
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)
        let request = try MockData.request()

        // WHEN / THEN
        var caughtError: (any Error)?
        do {
            for try await _ in await client.stream(request) {}
        } catch {
            caughtError = error
        }
        #expect(caughtError != nil)
    }

    // MARK: - Recipes

    @Test("send(recipe:) renders recipe and returns response")
    func sendRecipe_rendersAndReturnsResponse() async throws {
        // Given
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)
        let recipe = Recipe(
            id: "greet",
            name: "Greeter",
            systemPrompt: "You are friendly.",
            userPromptTemplate: "Say hello to {{name}}"
        )

        // When
        let response = try await client.send(
            recipe: recipe,
            values: ["name": "Alice"],
            model: "mock-model"
        )

        // Then
        #expect(response.id == MockData.response.id)
        #expect(provider.receivedRequests.count == 1)
        let sentRequest = provider.receivedRequests[0]
        #expect(sentRequest.systemPrompt == "You are friendly.")
        #expect(sentRequest.messages[0].text == "Say hello to Alice")
    }

    // MARK: - Skills

    @Test("execute(skillId:) runs skill and returns SkillResult")
    func executeSkill_runsAndReturnsResult() async throws {
        // Given
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)
        let skill = MockSkill(
            identifier: "test-skill",
            stubbedResult: SkillResult(
                output: "skill output",
                usage: TokenUsage(inputTokens: 10, outputTokens: 5)
            )
        )
        await client.skillRegistry.register(skill)

        // When
        let result = try await client.execute(
            skillId: "test-skill",
            input: "test input",
            model: "mock-model"
        )

        // Then
        #expect(result.output == "skill output")
        #expect(result.usage.totalTokens == 15)
    }

    @Test("execute(skillId:) throws skillNotFound for unknown id")
    func executeSkill_unknownId_throwsSkillNotFound() async {
        // Given
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)

        // When / Then
        await #expect(throws: AIError.self) {
            try await client.execute(
                skillId: "nonexistent",
                input: "test",
                model: "mock-model"
            )
        }
    }

    @Test("execute(skillId:) applies system prompt from skill recipe")
    func executeSkill_withRecipe_appliesSystemPrompt() async throws {
        // Given
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)
        let recipe = Recipe(
            id: "skill-recipe",
            name: "Skill Recipe",
            systemPrompt: "You are an expert analyzer.",
            userPromptTemplate: "Analyze this."
        )
        let skill = MockSkill(
            identifier: "analyzer",
            recipe: recipe,
            stubbedResult: SkillResult(
                output: "analysis",
                usage: TokenUsage(inputTokens: 8, outputTokens: 4)
            )
        )
        await client.skillRegistry.register(skill)

        // When
        _ = try await client.execute(
            skillId: "analyzer",
            input: "some data",
            model: "mock-model"
        )

        // Then
        #expect(provider.receivedRequests.count == 1)
        let sentRequest = provider.receivedRequests[0]
        #expect(sentRequest.systemPrompt == "You are an expert analyzer.")
    }
}
