import AIProviderKit
import AIProviderTools
import ClaudeProvider
import Foundation

// MARK: - Suite

actor ClaudeIntegrationSuite {
    private let client: AIClient
    private let runner = IntegrationSuiteRunner()

    init(apiKey: String) {
        client = AIClient(
            provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: apiKey))
        )
    }

    func runAll() async {
        print("═══════════════════════════════════════════")
        print("  AIProviderKit — Integration Tests")
        print("  Provider : Claude (Haiku)")
        print("═══════════════════════════════════════════\n")

        await runner.run("Basic text completion") { try await self.testBasicCompletion() }
        await runner.run("Streaming") { try await self.testStreaming() }
        await runner.run("Automatic tool execution") { try await self.testToolExecution() }
        await runner.run("Recipe rendering") { try await self.testRecipe() }
        await runner.run("Skill execution") { try await self.testSkill() }

        await runner.printSummary()
    }

    // MARK: - Tests

    /// Sends a simple user message and verifies a non-empty text response.
    private func testBasicCompletion() async throws {
        let request = try AIRequestBuilder()
            .model(ClaudeModel.haiku45)
            .addMessage(.user(text: "Reply with exactly one word: hello"))
            .maxTokens(16)
            .build()

        let response = try await client.send(request)

        guard !response.text.isEmpty        else { throw IntegrationError.emptyResponse }
        guard response.stopReason == .endTurn else { throw IntegrationError.unexpectedStopReason(response.stopReason) }
    }

    /// Streams a response and verifies that text deltas are received.
    private func testStreaming() async throws {
        let request = try AIRequestBuilder()
            .model(ClaudeModel.haiku45)
            .addMessage(.user(text: "Count from 1 to 3, one number per line."))
            .maxTokens(32)
            .build()

        var collected = ""
        let stream = await client.stream(request)
        for try await event in stream {
            if case .textDelta(let delta) = event { collected += delta }
        }

        guard !collected.isEmpty else { throw IntegrationError.emptyResponse }
    }

    /// Registers a `get_current_time` tool, asks Claude to call it, and
    /// verifies AIClient auto-executed the tool and completed in `endTurn`.
    private func testToolExecution() async throws {
        let timeTool = CurrentTimeTool.currentTime
        await client.toolRegistry.register(timeTool)

        let request = try AIRequestBuilder()
            .model(ClaudeModel.haiku45)
            .addMessage(.user(text: "What is the current time? Use the get_current_time tool."))
            .tools([timeTool])
            .maxTokens(256)
            .build()

        let response = try await client.send(request)

        guard response.stopReason == .endTurn else { throw IntegrationError.unexpectedStopReason(response.stopReason) }
        guard !response.text.isEmpty          else { throw IntegrationError.emptyResponse }
    }

    /// Renders a `Recipe` with placeholder values and verifies a response.
    private func testRecipe() async throws {
        let recipe = Recipe(
            id: "translate",
            name: "Translate",
            description: "Translates a word or phrase to a target language.",
            systemPrompt: "You are a concise translator. Reply with only the translation, no extra text.",
            userPromptTemplate: "Translate '{{text}}' to {{language}}."
        )

        let response = try await client.send(
            recipe: recipe,
            values: ["text": "hello", "language": "Spanish"],
            model: ClaudeModel.haiku45.aiModel
        )

        guard !response.text.isEmpty else { throw IntegrationError.emptyResponse }
    }

    /// Registers `SummarizerSkill`, executes it via `AIClient.execute`, and
    /// verifies the processed output is non-empty.
    private func testSkill() async throws {
        let skill = SummarizerSkill()
        await client.skillRegistry.register(skill)

        let result = try await client.execute(
            skillId: skill.identifier,
            input: "The quick brown fox jumps over the lazy dog. This classic pangram uses every letter of the alphabet.",
            model: ClaudeModel.haiku45.aiModel
        )

        guard !result.output.isEmpty else { throw IntegrationError.emptyResponse }
    }
}
