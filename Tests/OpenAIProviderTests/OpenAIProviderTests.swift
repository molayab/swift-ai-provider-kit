// swiftlint:disable file_length
import AIProviderKit
import Foundation
@testable import OpenAIProvider
import Testing

// swiftlint:disable type_body_length
@Suite("OpenAIProvider")
struct OpenAIProviderTests {

    // MARK: - Helpers

    private func makeProvider(httpClient: MockHTTPClient) -> OpenAIProvider {
        OpenAIProvider(
            authorization: MockBearerAuthorization(),
            httpClient: httpClient
        )
    }

    private func makeRequest() throws -> AIRequest {
        try AIRequestBuilder()
            .model(.gpt4o)
            .addMessage(.user(text: "Hello"))
            .build()
    }

    // MARK: - Identifier & Capabilities

    @Test("identifier is openai")
    func identifier_isOpenAI() {
        // Given
        let provider = makeProvider(httpClient: MockHTTPClient())

        // When
        let identifier = provider.identifier

        // Then
        #expect(identifier == "openai")
    }

    @Test("capabilities include text vision tools streaming systemPrompt modelDiscovery")
    func capabilities_includeExpectedSet() {
        // Given
        let provider = makeProvider(httpClient: MockHTTPClient())

        // When
        let capabilities = provider.capabilities

        // Then
        #expect(capabilities == [.text, .vision, .tools, .streaming, .systemPrompt, .modelDiscovery])
    }

    // MARK: - AIModel Constants

    @Test("AIModel constants have correct identifiers")
    func aiModelConstants_haveCorrectIdentifiers() {
        // Given / When / Then
        #expect(AIModel.gpt41.identifier == "gpt-4.1")
        #expect(AIModel.gpt41Mini.identifier == "gpt-4.1-mini")
        #expect(AIModel.gpt41Nano.identifier == "gpt-4.1-nano")
        #expect(AIModel.gpt4o.identifier == "gpt-4o")
        #expect(AIModel.gpt4oMini.identifier == "gpt-4o-mini")
        #expect(AIModel.o3.identifier == "o3")
        #expect(AIModel.o3Mini.identifier == "o3-mini")
        #expect(AIModel.o4Mini.identifier == "o4-mini")
    }

    // MARK: - send — Success

    @Test("send decodes successful text response")
    func send_decodesSuccessfulTextResponse() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: OpenAIResponseFixture.successJSON
        )
        let provider = makeProvider(httpClient: httpClient)
        let request = try makeRequest()

        // When
        let response = try await provider.send(request)

        // Then
        #expect(response.id == "chatcmpl-fixture-001")
        #expect(response.text == "Hello back!")
        #expect(response.usage.inputTokens == 10)
        #expect(response.usage.outputTokens == 5)
        #expect(response.stopReason == .endTurn)
    }

    @Test("send decodes tool_calls response into toolUse content blocks")
    func send_decodesToolCallsResponse() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: OpenAIResponseFixture.toolCallResponseJSON
        )
        let provider = makeProvider(httpClient: httpClient)
        let request = try makeRequest()

        // When
        let response = try await provider.send(request)

        // Then
        #expect(response.stopReason == .toolUse)
        #expect(response.toolUses.count == 1)
        #expect(response.toolUses[0].name == "get_weather")
        #expect(response.toolUses[0].id == "call_fixture_001")
        #expect(response.toolUses[0].input == .object(["city": .string("Rome")]))
    }

    // MARK: - send — Request Serialisation

    @Test("send serialises tools as function type in HTTP body")
    func send_serialisesToolsInBody() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: OpenAIResponseFixture.successJSON
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
            .model(.gpt4o)
            .addMessage(.user(text: "Weather in Rome?"))
            .addTool(tool)
            .build()

        // When
        _ = try await provider.send(request)

        // Then
        #expect(httpClient.receivedRequests.count == 1)
        let body = httpClient.receivedRequests[0].body
        let bodyString = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        #expect(bodyString.contains("\"type\":\"function\""))
        #expect(bodyString.contains("get_weather"))
        #expect(bodyString.contains("parameters"))
    }

    @Test("send serialises system prompt as first message in body")
    func send_serialisesSystemPromptInBody() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: OpenAIResponseFixture.successJSON
        )
        let provider = makeProvider(httpClient: httpClient)
        let request = try AIRequestBuilder()
            .model(.gpt4o)
            .systemPrompt("You are an expert.")
            .addMessage(.user(text: "Hello"))
            .build()

        // When
        _ = try await provider.send(request)

        // Then
        let body = httpClient.receivedRequests[0].body
        let bodyString = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        #expect(bodyString.contains("\"role\":\"system\""))
        #expect(bodyString.contains("You are an expert."))
    }

    // MARK: - send — Error Handling

    @Test("send throws rateLimitExceeded on HTTP 429")
    func send_throwsRateLimitExceeded() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(statusCode: 429, body: Data())
        let provider = makeProvider(httpClient: httpClient)
        let request = try makeRequest()

        // When / Then
        await #expect(throws: AIError.self) {
            try await provider.send(request)
        }
    }

    @Test("send throws invalidResponse on HTTP 500")
    func send_throwsOnServerError() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(statusCode: 500, body: Data("error".utf8))
        let provider = makeProvider(httpClient: httpClient)
        let request = try makeRequest()

        // When / Then
        await #expect(throws: AIError.self) {
            try await provider.send(request)
        }
    }

    @Test("send throws contextLengthExceeded on context_length_exceeded error code")
    func send_throwsContextLengthExceeded() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 400,
            body: OpenAIResponseFixture.contextLengthErrorJSON
        )
        let provider = makeProvider(httpClient: httpClient)
        let request = try makeRequest()

        // When / Then
        await #expect(throws: AIError.self) {
            try await provider.send(request)
        }
    }

    @Test("send throws networkError when URLError thrown")
    func send_throwsNetworkErrorOnURLError() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedError = URLError(.notConnectedToInternet)
        let provider = makeProvider(httpClient: httpClient)
        let request = try makeRequest()

        // When / Then
        await #expect(throws: AIError.self) {
            try await provider.send(request)
        }
    }

    // MARK: - stream

    @Test("stream yields text deltas from SSE events")
    func stream_yieldsTextDeltas() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedStreamData = OpenAIResponseFixture.textStreamChunks
        let provider = makeProvider(httpClient: httpClient)
        let request = try makeRequest()

        // When
        var deltas: [String] = []
        for try await event in provider.stream(request) {
            if case .textDelta(let text) = event { deltas.append(text) }
        }

        // Then
        #expect(deltas == ["Hello", " world"])
    }

    @Test("stream throws rateLimitExceeded when HTTP 429 is received before SSE data")
    func stream_throws_rateLimitExceeded_on429() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedStreamError = HTTPStreamError(statusCode: 429, body: Data())
        let provider = makeProvider(httpClient: httpClient)
        let request = try makeRequest()

        // When / Then
        await #expect(throws: AIError.self) {
            for try await _ in provider.stream(request) {}
        }
    }

    @Test("stream throws invalidResponse when HTTP 500 is received before SSE data")
    func stream_throws_invalidResponse_on500() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedStreamError = HTTPStreamError(
            statusCode: 500,
            body: Data("Internal Server Error".utf8)
        )
        let provider = makeProvider(httpClient: httpClient)
        let request = try makeRequest()

        // When / Then
        await #expect(throws: AIError.self) {
            for try await _ in provider.stream(request) {}
        }
    }

    // MARK: - listModels — Success

    @Test("listModels returns only chat-capable models filtered from API response")
    func listModels_filtersNonChatModels() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: OpenAIResponseFixture.modelsListJSON
        )
        let provider = makeProvider(httpClient: httpClient)

        // When
        let models = try await provider.listModels()

        // Then
        #expect(models.count == 2)
        let identifiers = models.map(\.model.identifier)
        #expect(identifiers.contains("gpt-4o"))
        #expect(identifiers.contains("o3-mini"))
    }

    @Test("listModels maps created timestamp to Date")
    func listModels_mapsCreatedTimestamp() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: OpenAIResponseFixture.singleModelJSON
        )
        let provider = makeProvider(httpClient: httpClient)

        // When
        let models = try await provider.listModels()

        // Then
        #expect(models.count == 1)
        #expect(models[0].createdAt != nil)
        #expect(models[0].createdAt == Date(timeIntervalSince1970: 1_705_696_900))
    }

    @Test("listModels maps model id to AIModel identifier")
    func listModels_mapsModelId() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: OpenAIResponseFixture.singleModelJSON
        )
        let provider = makeProvider(httpClient: httpClient)

        // When
        let models = try await provider.listModels()

        // Then
        #expect(models[0].model == AIModel("gpt-4o"))
    }

    // MARK: - listModels — Error Handling

    @Test("listModels throws rateLimitExceeded on HTTP 429")
    func listModels_throwsRateLimitExceeded() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(statusCode: 429, body: Data())
        let provider = makeProvider(httpClient: httpClient)

        // When / Then
        await #expect(throws: AIError.self) {
            try await provider.listModels()
        }
    }

    @Test("listModels throws networkError on URLError")
    func listModels_throwsNetworkErrorOnURLError() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedError = URLError(.notConnectedToInternet)
        let provider = makeProvider(httpClient: httpClient)

        // When / Then
        await #expect(throws: AIError.self) {
            try await provider.listModels()
        }
    }

    @Test("listModels throws invalidResponse on HTTP 500")
    func listModels_throwsOnServerError() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(statusCode: 500, body: Data("error".utf8))
        let provider = makeProvider(httpClient: httpClient)

        // When / Then
        await #expect(throws: AIError.self) {
            try await provider.listModels()
        }
    }
}
// swiftlint:enable type_body_length

// MARK: - Test Helpers

private struct MockBearerAuthorization: AuthorizationProvider {
    func authorizationHeaders() async throws(AIError) -> [String: String] {
        ["Authorization": "Bearer test-key"]
    }
}

private enum OpenAIResponseFixture {

    static let successJSON: Data = {
        let json = """
        {
            "id": "chatcmpl-fixture-001",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4o",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "Hello back!"},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        }
        """
        return Data(json.utf8)
    }()

    static let toolCallResponseJSON: Data = {
        let json = """
        {
            "id": "chatcmpl-fixture-002",
            "object": "chat.completion",
            "model": "gpt-4o",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_fixture_001",
                        "type": "function",
                        "function": {"name": "get_weather", "arguments": "{\\"city\\":\\"Rome\\"}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 20, "completion_tokens": 8, "total_tokens": 28}
        }
        """
        return Data(json.utf8)
    }()

    static let contextLengthErrorJSON: Data = {
        let json = """
        {
            "error": {
                "message": "This model's maximum context length is 128000 tokens.",
                "type": "invalid_request_error",
                "code": "context_length_exceeded"
            }
        }
        """
        return Data(json.utf8)
    }()

    static let modelsListJSON: Data = {
        let json = """
        {
            "object": "list",
            "data": [
                {"id": "gpt-4o", "object": "model", "created": 1705696900, "owned_by": "openai"},
                {"id": "text-embedding-3-large", "object": "model", "created": 1705696900, "owned_by": "openai"},
                {"id": "whisper-1", "object": "model", "created": 1677532384, "owned_by": "openai-internal"},
                {"id": "o3-mini", "object": "model", "created": 1705696900, "owned_by": "openai"},
                {"id": "dall-e-3", "object": "model", "created": 1698785189, "owned_by": "openai"}
            ]
        }
        """
        return Data(json.utf8)
    }()

    static let singleModelJSON: Data = {
        let json = """
        {
            "object": "list",
            "data": [
                {"id": "gpt-4o", "object": "model", "created": 1705696900, "owned_by": "openai"}
            ]
        }
        """
        return Data(json.utf8)
    }()

    static let textStreamChunks: [Data] = {
        let events = [
            // swiftlint:disable:next line_length
            #"{"id":"chatcmpl-s1","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"role":"assistant","content":"Hello"},"finish_reason":null}]}"#,
            // swiftlint:disable:next line_length
            #"{"id":"chatcmpl-s1","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":" world"},"finish_reason":null}]}"#
        ]
        return events.map { Data($0.utf8) }
    }()
}
