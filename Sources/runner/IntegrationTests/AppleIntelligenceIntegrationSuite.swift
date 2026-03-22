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
        await runner.printHeader(provider: "Apple Intelligence (on-device)")

        await runner.run("Basic text completion") { try await self.testBasicCompletion() }
        await runner.run("Streaming") { try await self.testStreaming() }
        await runner.run("Automatic tool execution") { try await self.testToolExecution() }
        await runner.runRecipeTest(client: client, model: AppleIntelligenceModel.default.aiModel)
        await runner.runSkillTest(client: client, model: AppleIntelligenceModel.default.aiModel)

        await runner.printSummary()
    }

    // MARK: - Tests

    private func testBasicCompletion() async throws {
        let request = try AIRequestBuilder()
            .model(AppleIntelligenceModel.default)
            .addMessage(.user(text: "Reply with exactly one word: hello"))
            .build()

        let response = try await client.send(request)

        guard !response.text.isEmpty else { throw IntegrationError.emptyResponse }
        guard response.stopReason == .endTurn else { throw IntegrationError.unexpectedStopReason(response.stopReason) }
    }

    private func testStreaming() async throws {
        let request = try AIRequestBuilder()
            .model(AppleIntelligenceModel.default)
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
            .model(AppleIntelligenceModel.default)
            .addMessage(.user(text: "What is the current time? Use the get_current_time tool."))
            .tools([timeTool])
            .build()

        let response = try await client.send(request)

        guard response.stopReason == .endTurn else { throw IntegrationError.unexpectedStopReason(response.stopReason) }
        guard !response.text.isEmpty else { throw IntegrationError.emptyResponse }
    }
}
