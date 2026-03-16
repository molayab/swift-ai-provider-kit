import AIProviderKit
@testable import AppleIntelligenceProvider
import Foundation
import Testing

@Suite("FMResponseMapper")
struct FMResponseMapperTests {

    // MARK: - Properties

    private let sut = FMResponseMapper()

    // MARK: - Text Response

    @Test("maps text response to text ContentBlock")
    func map_textResponse_producesTextBlock() {
        // Given
        let fmResponse = FMResponse(
            content: "hello",
            toolCalls: [],
            stopReason: .endTurn
        )

        // When
        let response = sut.map(fmResponse, model: "test-model")

        // Then
        #expect(response.content.count == 1)
        #expect(response.text == "hello")
    }

    // MARK: - Stop Reason Mapping

    @Test("maps endTurn stopReason")
    func map_endTurnStopReason_mapsCorrectly() {
        // Given
        let fmResponse = FMResponse(content: "", toolCalls: [], stopReason: .endTurn)

        // When
        let response = sut.map(fmResponse, model: "m")

        // Then
        #expect(response.stopReason == .endTurn)
    }

    @Test("maps maxTokens stopReason")
    func map_maxTokensStopReason_mapsCorrectly() {
        // Given
        let fmResponse = FMResponse(content: "", toolCalls: [], stopReason: .maxTokens)

        // When
        let response = sut.map(fmResponse, model: "m")

        // Then
        #expect(response.stopReason == .maxTokens)
    }

    @Test("maps toolUse stopReason")
    func map_toolUseStopReason_mapsCorrectly() {
        // Given
        let fmResponse = FMResponse(
            content: "",
            toolCalls: [FMToolCall(id: "t1", name: "fn", argumentsJSON: "{}")],
            stopReason: .toolUse
        )

        // When
        let response = sut.map(fmResponse, model: "m")

        // Then
        #expect(response.stopReason == .toolUse)
    }

    // MARK: - Tool Calls

    @Test("maps tool calls to toolUse ContentBlocks")
    func map_toolCalls_producesToolUseBlocks() {
        // Given
        let fmResponse = FMResponse(
            content: "",
            toolCalls: [
                FMToolCall(
                    id: "call_abc",
                    name: "get_weather",
                    argumentsJSON: #"{"city":"Rome"}"#
                )
            ],
            stopReason: .toolUse
        )

        // When
        let response = sut.map(fmResponse, model: "m")

        // Then
        #expect(response.toolUses.count == 1)
        #expect(response.toolUses[0].id == "call_abc")
        #expect(response.toolUses[0].name == "get_weather")
        #expect(response.toolUses[0].input == .object(["city": .string("Rome")]))
    }

    @Test("tool call with invalid JSON argument falls back to string JSONValue")
    func map_toolCallInvalidJSON_fallsBackToString() {
        // Given
        let fmResponse = FMResponse(
            content: "",
            toolCalls: [
                FMToolCall(id: "t1", name: "fn", argumentsJSON: "not-valid-json")
            ],
            stopReason: .toolUse
        )

        // When
        let response = sut.map(fmResponse, model: "m")

        // Then
        #expect(response.toolUses.count == 1)
        #expect(response.toolUses[0].input == .string("not-valid-json"))
    }

    @Test("tool call with empty id gets fallback id")
    func map_toolCallEmptyId_getsFallbackId() {
        // Given
        let fmResponse = FMResponse(
            content: "",
            toolCalls: [
                FMToolCall(id: "", name: "fn", argumentsJSON: "{}")
            ],
            stopReason: .toolUse
        )

        // When
        let response = sut.map(fmResponse, model: "m")

        // Then
        #expect(response.toolUses[0].id == "fm_tool_0")
    }

    // MARK: - Model Identifier

    @Test("uses provided model identifier")
    func map_modelIdentifier_passedThrough() {
        // Given
        let fmResponse = FMResponse(content: "ok", toolCalls: [], stopReason: .endTurn)

        // When
        let response = sut.map(fmResponse, model: "com.apple.foundation-models.default")

        // Then
        #expect(response.model == "com.apple.foundation-models.default")
    }

    // MARK: - Response ID

    @Test("response id is a non-empty UUID string")
    func map_responseId_isNonEmpty() {
        // Given
        let fmResponse = FMResponse(content: "ok", toolCalls: [], stopReason: .endTurn)

        // When
        let response = sut.map(fmResponse, model: "m")

        // Then
        #expect(!response.id.isEmpty)
    }

    // MARK: - Token Usage

    @Test("token usage is zero (FoundationModels does not report counts)")
    func map_tokenUsage_isZero() {
        // Given
        let fmResponse = FMResponse(content: "ok", toolCalls: [], stopReason: .endTurn)

        // When
        let response = sut.map(fmResponse, model: "m")

        // Then — FoundationModels does not expose token counts; callers detect
        // the zero and apply their own estimation (e.g. BenchmarkSuite char/4).
        #expect(response.usage.inputTokens == 0)
        #expect(response.usage.outputTokens == 0)
    }

    // MARK: - Stream Delta

    @Test("maps stream delta to textDelta event")
    func mapStreamDelta_text_producesTextDeltaEvent() {
        // Given
        let delta = FMStreamDelta(text: "hi")

        // When
        let event = sut.mapStreamDelta(delta)

        // Then
        if case .textDelta(let text) = event {
            #expect(text == "hi")
        } else {
            Issue.record("Expected textDelta event but got \(event)")
        }
    }
}
