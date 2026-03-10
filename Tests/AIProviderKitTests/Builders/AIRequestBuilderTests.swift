import Testing
import AIProviderKit

@Suite("AIRequestBuilder")
struct AIRequestBuilderTests {

    @Test("produces a valid request when all required fields are set")
    func buildSucceeds() throws {
        // GIVEN
        let builder = AIRequestBuilder()
            .model("test-model")
            .addMessage(.user(text: "Hello"))

        // WHEN
        let request = try builder.build()

        // THEN
        #expect(request.model.identifier == "test-model")
        #expect(request.messages.count == 1)
        #expect(request.messages[0].role == .user)
    }

    @Test("throws requestBuildingFailed when model is not set")
    func throwsWhenModelMissing() {
        // GIVEN
        let builder = AIRequestBuilder().addMessage(.user(text: "Hello"))

        // WHEN / THEN
        #expect(throws: AIError.self) { try builder.build() }
    }

    @Test("throws requestBuildingFailed when no messages are provided")
    func throwsWhenMessagesMissing() {
        // GIVEN
        let builder = AIRequestBuilder().model("test-model")

        // WHEN / THEN
        #expect(throws: AIError.self) { try builder.build() }
    }

    @Test("conversation builder appends messages in declared order")
    func conversationBuilderOrder() throws {
        // GIVEN
        let builder = AIRequestBuilder()
            .model("test-model")
            .conversation {
                Message.system("Be helpful.")
                Message.user(text: "Hi!")
                Message.assistant(text: "Hello!")
            }

        // WHEN
        let request = try builder.build()

        // THEN
        #expect(request.messages.count == 3)
        #expect(request.messages[0].role == .system)
        #expect(request.messages[1].role == .user)
        #expect(request.messages[2].role == .assistant)
    }

    @Test("optional parameters are forwarded to AIRequest")
    func optionalParametersForwarded() throws {
        // GIVEN
        let builder = AIRequestBuilder()
            .model("test-model")
            .addMessage(.user(text: "Hi"))
            .systemPrompt("You are an expert.")
            .temperature(0.7)
            .topP(0.9)
            .maxTokens(512)

        // WHEN
        let request = try builder.build()

        // THEN
        #expect(request.systemPrompt == "You are an expert.")
        #expect(request.temperature == 0.7)
        #expect(request.topP == 0.9)
        #expect(request.maxTokens == 512)
    }

    @Test("default maxTokens is 4096")
    func defaultMaxTokens() throws {
        // GIVEN / WHEN
        let request = try MockData.request()

        // THEN
        #expect(request.maxTokens == 4_096)
    }
}
