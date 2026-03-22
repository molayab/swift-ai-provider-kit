import AIProviderKit
import AIProviderTools
import Foundation
import OpenAIProvider

// MARK: - Suite

actor OpenAIIntegrationSuite {
    private let client: AIClient
    private let runner = IntegrationSuiteRunner()

    init(apiKey: String) {
        client = AIClient(
            provider: OpenAIProvider(authorization: BearerAuthorization(apiKey: apiKey))
        )
    }

    func runAll() async {
        await runner.printHeader(provider: "OpenAI (GPT-4.1 Mini)")

        await runner.run("Basic text completion") { try await self.testBasicCompletion() }
        await runner.run("Streaming") { try await self.testStreaming() }
        await runner.run("Automatic tool execution") { try await self.testToolExecution() }
        await runner.runRecipeTest(client: client, model: OpenAIModel.gpt41Mini.aiModel)
        await runner.runSkillTest(client: client, model: OpenAIModel.gpt41Mini.aiModel)
        await runner.run("Model discovery") { try await self.testModelDiscovery() }

        await runner.printSummary()
    }

    // MARK: - Tests

    private func testBasicCompletion() async throws {
        let request = try AIRequestBuilder()
            .model(OpenAIModel.gpt41Mini)
            .addMessage(.user(text: "Reply with exactly one word: hello"))
            .maxTokens(16)
            .build()

        let response = try await client.send(request)

        guard !response.text.isEmpty else { throw IntegrationError.emptyResponse }
        guard response.stopReason == .endTurn else { throw IntegrationError.unexpectedStopReason(response.stopReason) }
    }

    private func testStreaming() async throws {
        let request = try AIRequestBuilder()
            .model(OpenAIModel.gpt41Mini)
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

    private func testToolExecution() async throws {
        let timeTool = CurrentTimeTool.currentTime
        await client.toolRegistry.register(timeTool)

        let request = try AIRequestBuilder()
            .model(OpenAIModel.gpt41Mini)
            .addMessage(.user(text: "What is the current time? Use the get_current_time tool."))
            .tools([timeTool])
            .maxTokens(256)
            .build()

        let response = try await client.send(request)

        guard response.stopReason == .endTurn else { throw IntegrationError.unexpectedStopReason(response.stopReason) }
        guard !response.text.isEmpty else { throw IntegrationError.emptyResponse }
    }

    private func testModelDiscovery() async throws {
        guard let provider = client.provider, let discovery = provider as? any ModelDiscoveryProvider else {
            throw IntegrationError.capabilityUnavailable("ModelDiscovery")
        }

        let models = try await discovery.listModels()
        guard !models.isEmpty else { throw IntegrationError.emptyResponse }
    }
}
