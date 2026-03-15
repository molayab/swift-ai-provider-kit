import AIProviderKit
import Foundation
@testable import OpenAIProvider
import Testing

@Suite("OpenAIResponseMapper")
struct OpenAIResponseMapperTests {

    let sut = OpenAIResponseMapper()

    // MARK: - Helpers

    private func makeResponse(
        id: String = "chatcmpl-test",
        model: String = "gpt-4o",
        content: String? = "Hello!",
        toolCalls: [OpenAIToolCall]? = nil,
        finishReason: String? = "stop",
        promptTokens: Int = 10,
        completionTokens: Int = 5
    ) -> OpenAIChatResponse {
        OpenAIChatResponse(
            id: id,
            model: model,
            choices: [
                OpenAIChoice(
                    index: 0,
                    message: OpenAIResponseMessage(
                        role: "assistant",
                        content: content,
                        toolCalls: toolCalls
                    ),
                    finishReason: finishReason
                )
            ],
            usage: OpenAIUsage(
                promptTokens: promptTokens,
                completionTokens: completionTokens
            )
        )
    }

    private func makeEmptyChoicesResponse() -> OpenAIChatResponse {
        OpenAIChatResponse(
            id: "chatcmpl-empty",
            model: "gpt-4o",
            choices: [],
            usage: OpenAIUsage(promptTokens: 0, completionTokens: 0)
        )
    }

    // MARK: - map — Text Content

    @Test("map produces AIResponse with text content block")
    func map_textContent_producesTextBlock() {
        // Given
        let response = makeResponse(content: "Hello!")

        // When
        let result = sut.map(response)

        // Then
        #expect(result.content.count == 1)
        #expect(result.text == "Hello!")
        #expect(result.id == "chatcmpl-test")
        #expect(result.model == "gpt-4o")
    }

    // MARK: - map — Tool Use

    @Test("map produces AIResponse with toolUse content block from tool_calls")
    func map_toolCalls_producesToolUseBlock() {
        // Given
        let toolCall = OpenAIToolCall(
            id: "call_001",
            type: "function",
            function: OpenAIFunctionCall(
                name: "get_weather",
                arguments: #"{"city":"Rome"}"#
            )
        )
        let response = makeResponse(content: nil, toolCalls: [toolCall], finishReason: "tool_calls")

        // When
        let result = sut.map(response)

        // Then
        #expect(result.toolUses.count == 1)
        #expect(result.toolUses[0].id == "call_001")
        #expect(result.toolUses[0].name == "get_weather")
    }

    @Test("map decodes arguments JSON string into JSONValue")
    func map_decodesArgumentsJSON() {
        // Given
        let toolCall = OpenAIToolCall(
            id: "call_002",
            type: "function",
            function: OpenAIFunctionCall(
                name: "get_weather",
                arguments: #"{"city":"Rome"}"#
            )
        )
        let response = makeResponse(content: nil, toolCalls: [toolCall])

        // When
        let result = sut.map(response)

        // Then
        #expect(result.toolUses[0].input == .object(["city": .string("Rome")]))
    }

    // MARK: - map — Usage

    @Test("map maps prompt_tokens to inputTokens")
    func map_promptTokens_toInputTokens() {
        // Given
        let response = makeResponse(promptTokens: 42, completionTokens: 10)

        // When
        let result = sut.map(response)

        // Then
        #expect(result.usage.inputTokens == 42)
    }

    @Test("map maps completion_tokens to outputTokens")
    func map_completionTokens_toOutputTokens() {
        // Given
        let response = makeResponse(promptTokens: 10, completionTokens: 99)

        // When
        let result = sut.map(response)

        // Then
        #expect(result.usage.outputTokens == 99)
    }

    // MARK: - mapFinishReason

    @Test("mapFinishReason stop maps to endTurn")
    func mapFinishReason_stop_mapsToEndTurn() {
        // Given
        let response = makeResponse(finishReason: "stop")

        // When
        let result = sut.map(response)

        // Then
        #expect(result.stopReason == .endTurn)
    }

    @Test("mapFinishReason length maps to maxTokens")
    func mapFinishReason_length_mapsToMaxTokens() {
        // Given
        let response = makeResponse(finishReason: "length")

        // When
        let result = sut.map(response)

        // Then
        #expect(result.stopReason == .maxTokens)
    }

    @Test("mapFinishReason tool_calls maps to toolUse")
    func mapFinishReason_toolCalls_mapsToToolUse() {
        // Given
        let response = makeResponse(finishReason: "tool_calls")

        // When
        let result = sut.map(response)

        // Then
        #expect(result.stopReason == .toolUse)
    }

    @Test("mapFinishReason content_filter maps to unknown")
    func mapFinishReason_contentFilter_mapsToUnknown() {
        // Given
        let response = makeResponse(finishReason: "content_filter")

        // When
        let result = sut.map(response)

        // Then
        #expect(result.stopReason == .unknown)
    }

    @Test("mapFinishReason nil maps to unknown")
    func mapFinishReason_nil_mapsToUnknown() {
        // Given
        let response = makeResponse(finishReason: nil)

        // When
        let result = sut.map(response)

        // Then
        #expect(result.stopReason == .unknown)
    }

    // MARK: - map — Empty Choices

    @Test("map returns unknown stopReason when choices is empty")
    func map_emptyChoices_returnsUnknownStopReason() {
        // Given
        let response = makeEmptyChoicesResponse()

        // When
        let result = sut.map(response)

        // Then
        #expect(result.stopReason == .unknown)
        #expect(result.content.isEmpty)
    }

    // MARK: - mapStreamEvent — Text Delta

    @Test("mapStreamEvent returns textDelta for content delta")
    func mapStreamEvent_contentDelta_returnsTextDelta() throws {
        // Given
        let json = """
        {"id":"chatcmpl-s1","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}
        """
        let data = Data(json.utf8)

        // When
        let events = try sut.mapStreamEvent(data)

        // Then
        #expect(events.count == 1)
        if case .textDelta(let text) = events.first {
            #expect(text == "Hello")
        } else {
            Issue.record("Expected .textDelta event")
        }
    }

    // MARK: - mapStreamEvent — Tool Use Delta

    @Test("mapStreamEvent returns one toolUseDelta per identified tool call in chunk")
    func mapStreamEvent_toolCallsDelta_returnsToolUseDelta() throws {
        // Given
        // swiftlint:disable:next line_length
        let json = #"{"id":"chatcmpl-s2","choices":[{"index":0,"delta":{"role":"assistant","content":null,"tool_calls":[{"index":0,"id":"call_s001","type":"function","function":{"name":"get_weather","arguments":""}}]},"finish_reason":null}]}"#
        let data = Data(json.utf8)

        // When
        let events = try sut.mapStreamEvent(data)

        // Then
        #expect(events.count == 1)
        if case .toolUseDelta(let id, let name, _) = events.first {
            #expect(id == "call_s001")
            #expect(name == "get_weather")
        } else {
            Issue.record("Expected .toolUseDelta event")
        }
    }

    @Test("mapStreamEvent returns one event per identified tool call when chunk contains multiple")
    func mapStreamEvent_multipleToolCallsInChunk_returnsOneEventEach() throws {
        // Given — chunk carries two parallel tool calls, each with id and name
        // swiftlint:disable:next line_length
        let json = #"{"id":"chatcmpl-s3","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_A","type":"function","function":{"name":"tool_a","arguments":""}},{"index":1,"id":"call_B","type":"function","function":{"name":"tool_b","arguments":""}}]},"finish_reason":null}]}"#
        let data = Data(json.utf8)

        // When
        let events = try sut.mapStreamEvent(data)

        // Then
        #expect(events.count == 2)
        if case .toolUseDelta(let id, let name, _) = events.first {
            #expect(id == "call_A")
            #expect(name == "tool_a")
        } else {
            Issue.record("Expected first .toolUseDelta event")
        }
        if case .toolUseDelta(let id, let name, _) = events.last {
            #expect(id == "call_B")
            #expect(name == "tool_b")
        } else {
            Issue.record("Expected second .toolUseDelta event")
        }
    }

    @Test("mapStreamEvent returns empty for argument-only tool_calls chunk (no id or name)")
    func mapStreamEvent_toolCallsArgOnlyChunk_returnsEmpty() throws {
        // Given — subsequent OpenAI streaming chunks carry only `arguments`, no id or name.
        // mapStreamEvent is stateless and cannot correlate these to a prior tool call.
        // swiftlint:disable:next line_length
        let json = #"{"id":"chatcmpl-s2","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"loc"}}]},"finish_reason":null}]}"#
        let data = Data(json.utf8)

        // When
        let events = try sut.mapStreamEvent(data)

        // Then
        #expect(events.isEmpty)
    }

    // MARK: - mapStreamEvent — Empty Delta

    @Test("mapStreamEvent returns empty for empty delta")
    func mapStreamEvent_emptyDelta_returnsEmpty() throws {
        // Given
        let json = #"{"id":"chatcmpl-s1","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}"#
        let data = Data(json.utf8)

        // When
        let events = try sut.mapStreamEvent(data)

        // Then
        #expect(events.isEmpty)
    }

    // MARK: - mapStreamEvent — Invalid JSON

    @Test("mapStreamEvent throws decodingFailed for invalid JSON")
    func mapStreamEvent_invalidJSON_throwsDecodingFailed() {
        // Given
        let data = Data("not json at all".utf8)

        // When / Then
        #expect(throws: AIError.self) {
            try sut.mapStreamEvent(data)
        }
    }
}
