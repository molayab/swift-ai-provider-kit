import AIProviderKit
import AIProviderTools
import AppleIntelligenceProvider
import Foundation

// MARK: - Suite

actor AppleIntelligenceIntegrationSuite {
    private let client: AIClient
    private let runner = IntegrationSuiteRunner()

    init() {
        client = AIClient(provider: AppleIntelligenceProvider())
    }

    func runAll() async {
        print("═══════════════════════════════════════════")
        print("  AIProviderKit — Integration Tests")
        print("  Provider : Apple Intelligence (on-device)")
        print("═══════════════════════════════════════════\n")

        await runner.run("Basic text completion") { try await self.testBasicCompletion() }
        await runner.run("Streaming") { try await self.testStreaming() }
        await runner.run("Automatic tool execution") { try await self.testToolExecution() }
        await runner.run("Recipe rendering") { try await self.testRecipe() }
        await runner.run("Skill execution") { try await self.testSkill() }

        await runner.printSummary()
    }

    // MARK: - Tests

    private func testBasicCompletion() async throws {
        let request = try AIRequestBuilder()
            .model(.appleIntelligenceDefault)
            .addMessage(.user(text: "Reply with exactly one word: hello"))
            .build()

        let response = try await client.send(request)

        guard !response.text.isEmpty else { throw IntegrationError.emptyResponse }
        guard response.stopReason == .endTurn else { throw IntegrationError.unexpectedStopReason(response.stopReason) }
    }

    private func testStreaming() async throws {
        let request = try AIRequestBuilder()
            .model(.appleIntelligenceDefault)
            .addMessage(.user(text: "Count from 1 to 3, one number per line."))
            .build()

        var collected = ""
        for try await event in await client.stream(request) {
            if case .textDelta(let delta) = event { collected += delta }
        }

        guard !collected.isEmpty else { throw IntegrationError.emptyResponse }
    }

    private func testToolExecution() async throws {
        let timeTool = CurrentTimeTool.currentTime
        await client.toolRegistry.register(timeTool)

        let request = try AIRequestBuilder()
            .model(.appleIntelligenceDefault)
            .addMessage(.user(text: "What is the current time? Use the get_current_time tool."))
            .tools([timeTool])
            .build()

        let response = try await client.send(request)

        guard response.stopReason == .endTurn else { throw IntegrationError.unexpectedStopReason(response.stopReason) }
        guard !response.text.isEmpty else { throw IntegrationError.emptyResponse }
    }

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
            model: .appleIntelligenceDefault
        )

        guard !response.text.isEmpty else { throw IntegrationError.emptyResponse }
    }

    private func testSkill() async throws {
        let skill = SummarizerSkill()
        await client.skillRegistry.register(skill)

        let result = try await client.execute(
            skillId: skill.identifier,
            input: "The quick brown fox jumps over the lazy dog. This classic pangram uses every letter of the alphabet.",
            model: .appleIntelligenceDefault
        )

        guard !result.output.isEmpty else { throw IntegrationError.emptyResponse }
    }
}
