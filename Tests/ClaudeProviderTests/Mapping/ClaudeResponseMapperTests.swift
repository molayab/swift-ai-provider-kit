import AIProviderKit
@testable import ClaudeProvider
import Foundation
import Testing

@Suite("ClaudeResponseMapper")
struct ClaudeResponseMapperTests {

    let sut = ClaudeResponseMapper()

    // MARK: - Helpers

    private func makeClaudeResponse(
        content: [ClaudeContentBlock],
        stopReason: String? = "end_turn"
    ) -> ClaudeResponse {
        ClaudeResponse(
            id: "msg_test",
            model: "claude-sonnet-4-6",
            content: content,
            stopReason: stopReason,
            usage: ClaudeUsage(inputTokens: 10, outputTokens: 5)
        )
    }

    private func textBlock(_ text: String) -> ClaudeContentBlock {
        ClaudeContentBlock(
            type: "text",
            text: text,
            source: nil,
            id: nil,
            name: nil,
            input: nil,
            toolUseId: nil,
            content: nil,
            isError: nil
        )
    }

    private func toolUseBlock(id: String, name: String, input: JSONValue) -> ClaudeContentBlock {
        ClaudeContentBlock(
            type: "tool_use",
            text: nil,
            source: nil,
            id: id,
            name: name,
            input: input,
            toolUseId: nil,
            content: nil,
            isError: nil
        )
    }

    private func unknownBlock() -> ClaudeContentBlock {
        ClaudeContentBlock(
            type: "thinking",
            text: "internal reasoning",
            source: nil,
            id: nil,
            name: nil,
            input: nil,
            toolUseId: nil,
            content: nil,
            isError: nil
        )
    }

    // MARK: - map (Full Response)

    @Test("map with text content block produces AIResponse with .text")
    func map_textContent_producesTextBlock() {
        // Given
        let claudeResponse = makeClaudeResponse(content: [textBlock("Hello!")])

        // When
        let result = sut.map(claudeResponse)

        // Then
        #expect(result.content.count == 1)
        #expect(result.text == "Hello!")
        #expect(result.id == "msg_test")
        #expect(result.model == "claude-sonnet-4-6")
    }

    @Test("map with tool_use content block produces AIResponse with .toolUse")
    func map_toolUseContent_producesToolUseBlock() {
        // Given
        let block = toolUseBlock(id: "t1", name: "calc", input: ["x": 5])
        let claudeResponse = makeClaudeResponse(content: [block])

        // When
        let result = sut.map(claudeResponse)

        // Then
        #expect(result.toolUses.count == 1)
        #expect(result.toolUses[0].id == "t1")
        #expect(result.toolUses[0].name == "calc")
        #expect(result.toolUses[0].input["x"]?.intValue == 5)
    }

    @Test("map skips unknown content block type")
    func map_unknownContentType_isSkipped() {
        // Given
        let claudeResponse = makeClaudeResponse(content: [
            textBlock("visible"),
            unknownBlock()
        ])

        // When
        let result = sut.map(claudeResponse)

        // Then
        #expect(result.content.count == 1)
        #expect(result.text == "visible")
    }

    @Test("map forwards usage tokens correctly")
    func map_forwardsUsage() {
        // Given
        let claudeResponse = makeClaudeResponse(content: [textBlock("ok")])

        // When
        let result = sut.map(claudeResponse)

        // Then
        #expect(result.usage.inputTokens == 10)
        #expect(result.usage.outputTokens == 5)
    }

    // MARK: - mapStopReason

    @Test("mapStopReason maps end_turn to .endTurn")
    func mapStopReason_endTurn() {
        // Given
        let claudeResponse = makeClaudeResponse(content: [textBlock("ok")], stopReason: "end_turn")

        // When
        let result = sut.map(claudeResponse)

        // Then
        #expect(result.stopReason == .endTurn)
    }

    @Test("mapStopReason maps max_tokens to .maxTokens")
    func mapStopReason_maxTokens() {
        // Given
        let claudeResponse = makeClaudeResponse(content: [textBlock("truncated")], stopReason: "max_tokens")

        // When
        let result = sut.map(claudeResponse)

        // Then
        #expect(result.stopReason == .maxTokens)
    }

    @Test("mapStopReason maps stop_sequence to .stopSequence")
    func mapStopReason_stopSequence() {
        // Given
        let claudeResponse = makeClaudeResponse(content: [textBlock("ok")], stopReason: "stop_sequence")

        // When
        let result = sut.map(claudeResponse)

        // Then
        #expect(result.stopReason == .stopSequence)
    }

    @Test("mapStopReason maps tool_use to .toolUse")
    func mapStopReason_toolUse() {
        // Given
        let block = toolUseBlock(id: "t1", name: "tool", input: .null)
        let claudeResponse = makeClaudeResponse(content: [block], stopReason: "tool_use")

        // When
        let result = sut.map(claudeResponse)

        // Then
        #expect(result.stopReason == .toolUse)
    }

    @Test("mapStopReason maps unknown string to .unknown")
    func mapStopReason_unknownString_returnsUnknown() {
        // Given
        let claudeResponse = makeClaudeResponse(content: [textBlock("ok")], stopReason: "something_new")

        // When
        let result = sut.map(claudeResponse)

        // Then
        #expect(result.stopReason == .unknown)
    }

    @Test("mapStopReason maps nil to .unknown")
    func mapStopReason_nil_returnsUnknown() {
        // Given
        let claudeResponse = makeClaudeResponse(content: [textBlock("ok")], stopReason: nil)

        // When
        let result = sut.map(claudeResponse)

        // Then
        #expect(result.stopReason == .unknown)
    }

    // MARK: - mapStreamEvent

    @Test("mapStreamEvent with text_delta returns .textDelta")
    func mapStreamEvent_textDelta_returnsTextDelta() throws {
        // Given
        let json = #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}"#
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

    @Test("mapStreamEvent with non-text event returns nil")
    func mapStreamEvent_nonTextEvent_returnsNil() throws {
        // Given
        let json = #"{"type":"message_start","message":{}}"#
        let data = Data(json.utf8)

        // When
        let event = try sut.mapStreamEvent(data)

        // Then
        #expect(event == nil)
    }

    @Test("mapStreamEvent with content_block_start returns nil")
    func mapStreamEvent_contentBlockStart_returnsNil() throws {
        // Given
        let json = #"{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#
        let data = Data(json.utf8)

        // When
        let event = try sut.mapStreamEvent(data)

        // Then
        #expect(event == nil)
    }

    @Test("mapStreamEvent with malformed JSON throws")
    func mapStreamEvent_malformedJSON_throws() {
        // Given
        let data = Data("not json at all".utf8)

        // When / Then
        #expect(throws: (any Error).self) {
            try sut.mapStreamEvent(data)
        }
    }

    @Test("mapStreamEvent with content_block_delta but non-text delta type returns nil")
    func mapStreamEvent_nonTextDeltaType_returnsNil() throws {
        // Given
        let json = #"{"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{"}}"#
        let data = Data(json.utf8)

        // When
        let event = try sut.mapStreamEvent(data)

        // Then
        #expect(event == nil)
    }
}
