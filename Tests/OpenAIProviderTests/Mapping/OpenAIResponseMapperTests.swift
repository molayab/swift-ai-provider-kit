import AIProviderKit
@testable import OpenAIProvider
import Foundation
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
        let event = try sut.mapStreamEvent(data)

        // Then
        if case .textDelta(let text) = event {
            #expect(text == "Hello")
        } else {
            Issue.record("Expected .textDelta event")
        }
    }

    // MARK: - mapStreamEvent — Tool Use Delta

    @Test("mapStreamEvent returns toolUseDelta for tool_calls delta")
    func mapStreamEvent_toolCallsDelta_returnsToolUseDelta() throws {
        // Given
        // swiftlint:disable:next line_length
        let json = #"{"id":"chatcmpl-s2","choices":[{"index":0,"delta":{"role":"assistant","content":null,"tool_calls":[{"index":0,"id":"call_s001","type":"function","function":{"name":"get_weather","arguments":""}}]},"finish_reason":null}]}"#
        let data = Data(json.utf8)

        // When
        let event = try sut.mapStreamEvent(data)

        // Then
        if case .toolUseDelta(let id, let name, _) = event {
            #expect(id == "call_s001")
            #expect(name == "get_weather")
        } else {
            Issue.record("Expected .toolUseDelta event")
        }
    }

    @Test("mapStreamEvent returns nil for argument-only tool_calls chunk (no id or name)")
    func mapStreamEvent_toolCallsArgOnlyChunk_returnsNil() throws {
        // Given — subsequent OpenAI streaming chunks carry only `arguments`, no id or name.
        // mapStreamEvent is stateless and cannot correlate these to a prior tool call,
        // so it must return nil rather than yielding a toolUseDelta with empty id/name.
        let json = #"{"id":"chatcmpl-s2","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"loc"}}]},"finish_reason":null}]}"#
        let data = Data(json.utf8)

        // When
        let event = try sut.mapStreamEvent(data)

        // Then
        #expect(event == nil)
    }

    // MARK: - mapStreamEvent — Empty Delta

    @Test("mapStreamEvent returns nil for empty delta")
    func mapStreamEvent_emptyDelta_returnsNil() throws {
        // Given
        let json = #"{"id":"chatcmpl-s1","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}"#
        let data = Data(json.utf8)

        // When
        let event = try sut.mapStreamEvent(data)

        // Then
        #expect(event == nil)
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
