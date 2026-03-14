import AIProviderKit
@testable import ClaudeProvider
import Foundation
import Testing

@Suite("ClaudeProvider")
struct ClaudeProviderTests {

    private func makeProvider(httpClient: MockHTTPClient) -> ClaudeProvider {
        ClaudeProvider(
            authorization: MockAPIKeyAuthorization(),
            httpClient: httpClient
        )
    }

    @Test("send encodes request and decodes successful response")
    func sendDecodesResponse() async throws {
        // GIVEN
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: ClaudeResponseFixture.successJSON
        )
        let provider = makeProvider(httpClient: httpClient)
        let request = try AIRequestBuilder()
            .model(.claudeSonnet4)
            .addMessage(.user(text: "Hello"))
            .build()

        // WHEN
        let response = try await provider.send(request)

        // THEN
        #expect(response.id == "msg_fixture_001")
        #expect(response.text == "Hello back!")
        #expect(response.usage.inputTokens == 10)
        #expect(response.stopReason == .endTurn)
    }

    @Test("send throws rateLimitExceeded on HTTP 429")
    func sendThrowsRateLimitExceeded() async throws {
        // GIVEN
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(statusCode: 429, body: Data())
        let provider = makeProvider(httpClient: httpClient)
        let request = try AIRequestBuilder()
            .model(.claudeSonnet4)
            .addMessage(.user(text: "Hello"))
            .build()

        // WHEN / THEN
        await #expect(throws: AIError.self) {
            try await provider.send(request)
        }
    }

    @Test("send throws invalidResponse on HTTP 500")
    func sendThrowsOnServerError() async throws {
        // GIVEN
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(statusCode: 500, body: Data("error".utf8))
        let provider = makeProvider(httpClient: httpClient)
        let request = try AIRequestBuilder()
            .model(.claudeSonnet4)
            .addMessage(.user(text: "Hello"))
            .build()

        // WHEN / THEN
        await #expect(throws: AIError.self) {
            try await provider.send(request)
        }
    }

    @Test("stream yields text deltas from SSE events")
    func streamYieldsTextDeltas() async throws {
        // GIVEN
        let httpClient = MockHTTPClient()
        httpClient.stubbedStreamData = ClaudeResponseFixture.streamChunks
        let provider = makeProvider(httpClient: httpClient)
        let request = try AIRequestBuilder()
            .model(.claudeSonnet4)
            .addMessage(.user(text: "Hello"))
            .build()

        // WHEN
        var deltas: [String] = []
        for try await event in provider.stream(request) {
            if case .textDelta(let text) = event { deltas.append(text) }
        }

        // THEN
        #expect(deltas == ["Hello", " world"])
    }

    // MARK: - Tool Use in Request

    @Test("tool use in request serialises tools in HTTP body")
    func sendWithTools_serialisesToolsInBody() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: ClaudeResponseFixture.successJSON
        )
        let provider = makeProvider(httpClient: httpClient)
        let tool = Tool(
            name: "get_weather",
            description: "Gets weather",
            inputSchema: .object(
                properties: ["city": .string(description: "City name")],
                required: ["city"]
            )
        ) { _ async in .null }
        let request = try AIRequestBuilder()
            .model(.claudeSonnet4)
            .addMessage(.user(text: "Weather in Rome?"))
            .addTool(tool)
            .build()

        // When
        _ = try await provider.send(request)

        // Then
        #expect(httpClient.receivedRequests.count == 1)
        let body = httpClient.receivedRequests[0].body
        let bodyString = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        #expect(bodyString.contains("get_weather"))
        #expect(bodyString.contains("input_schema"))
    }

    // MARK: - System Prompt in Request

    @Test("system prompt in request is sent as top-level system in body")
    func sendWithSystemPrompt_sendsSystemInBody() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: ClaudeResponseFixture.successJSON
        )
        let provider = makeProvider(httpClient: httpClient)
        let request = try AIRequestBuilder()
            .model(.claudeSonnet4)
            .systemPrompt("You are an expert.")
            .addMessage(.user(text: "Hello"))
            .build()

        // When
        _ = try await provider.send(request)

        // Then
        let body = httpClient.receivedRequests[0].body
        let bodyString = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        #expect(bodyString.contains("\"system\":\"You are an expert.\""))
    }

    // MARK: - Context Length Exceeded

    @Test("contextLengthExceeded error parsed from response body")
    func sendContextLengthExceeded_throwsContextLengthExceeded() async throws {
        // Given
        let httpClient = MockHTTPClient()
        let errorJSON = """
        {
            "type": "error",
            "error": {
                "type": "invalid_request_error",
                "message": "Request exceeded the model's context length limit."
            }
        }
        """
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 400,
            body: Data(errorJSON.utf8)
        )
        let provider = makeProvider(httpClient: httpClient)
        let request = try AIRequestBuilder()
            .model(.claudeSonnet4)
            .addMessage(.user(text: "Hello"))
            .build()

        // When / Then
        await #expect(throws: AIError.self) {
            try await provider.send(request)
        }
    }
}

// MARK: - Test Helpers

private struct MockAPIKeyAuthorization: AuthorizationProvider {
    func authorizationHeaders() async throws(AIError) -> [String: String] {
        ["x-api-key": "test-key"]
    }
}

private enum ClaudeResponseFixture {

    static let successJSON: Data = {
        let json = """
        {
            "id": "msg_fixture_001",
            "type": "message",
            "role": "assistant",
            "model": "claude-sonnet-4-6",
            "content": [{"type": "text", "text": "Hello back!"}],
            "stop_reason": "end_turn",
            "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        """
        return Data(json.utf8)
    }()

    static let streamChunks: [Data] = {
        let events = [
            #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}"#,
            #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}"#
        ]
        return events.compactMap { Data($0.utf8) }
    }()
}
