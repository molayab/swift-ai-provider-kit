import Testing
@testable import AIProviderKit

@Suite("AIResponse")
struct AIResponseTests {

    // MARK: - text

    @Test("text concatenates all text content blocks")
    func text_multipleTextBlocks_concatenatesAll() {
        // Given
        let response = AIResponse(
            id: "r1",
            model: "model",
            content: [.text("Hello "), .text("world")],
            usage: TokenUsage(inputTokens: 5, outputTokens: 3),
            stopReason: .endTurn
        )

        // When
        let result = response.text

        // Then
        #expect(result == "Hello world")
    }

    @Test("text returns empty string when no text blocks")
    func text_noTextBlocks_returnsEmpty() {
        // Given
        let response = AIResponse(
            id: "r2",
            model: "model",
            content: [.toolUse(.init(id: "t1", name: "tool", input: .null))],
            usage: TokenUsage(inputTokens: 5, outputTokens: 3),
            stopReason: .toolUse
        )

        // When
        let result = response.text

        // Then
        #expect(result == "")
    }

    @Test("text skips non-text blocks")
    func text_mixedContent_skipsNonText() {
        // Given
        let response = AIResponse(
            id: "r3",
            model: "model",
            content: [
                .text("Part 1"),
                .toolUse(.init(id: "t1", name: "tool", input: .null)),
                .text("Part 2")
            ],
            usage: TokenUsage(inputTokens: 5, outputTokens: 3),
            stopReason: .endTurn
        )

        // When
        let result = response.text

        // Then
        #expect(result == "Part 1Part 2")
    }

    // MARK: - toolUses

    @Test("toolUses extracts only toolUse content blocks")
    func toolUses_mixedContent_extractsToolUses() {
        // Given
        let toolUse1 = ContentBlock.ToolUseContent(id: "t1", name: "tool_a", input: .null)
        let toolUse2 = ContentBlock.ToolUseContent(id: "t2", name: "tool_b", input: .null)
        let response = AIResponse(
            id: "r4",
            model: "model",
            content: [
                .text("Thinking..."),
                .toolUse(toolUse1),
                .toolUse(toolUse2)
            ],
            usage: TokenUsage(inputTokens: 5, outputTokens: 3),
            stopReason: .toolUse
        )

        // When
        let result = response.toolUses

        // Then
        #expect(result.count == 2)
        #expect(result[0].name == "tool_a")
        #expect(result[1].name == "tool_b")
    }

    @Test("toolUses returns empty array when no tool use blocks")
    func toolUses_noToolUseBlocks_returnsEmpty() {
        // Given
        let response = AIResponse(
            id: "r5",
            model: "model",
            content: [.text("Just text")],
            usage: TokenUsage(inputTokens: 5, outputTokens: 3),
            stopReason: .endTurn
        )

        // When
        let result = response.toolUses

        // Then
        #expect(result.isEmpty)
    }

    // MARK: - requiresToolExecution

    @Test("requiresToolExecution is true when stopReason is toolUse")
    func requiresToolExecution_toolUseStop_returnsTrue() {
        // Given
        let response = AIResponse(
            id: "r6",
            model: "model",
            content: [.toolUse(.init(id: "t1", name: "tool", input: .null))],
            usage: TokenUsage(inputTokens: 5, outputTokens: 3),
            stopReason: .toolUse
        )

        // When
        let result = response.requiresToolExecution

        // Then
        #expect(result == true)
    }

    @Test("requiresToolExecution is false when stopReason is endTurn")
    func requiresToolExecution_endTurnStop_returnsFalse() {
        // Given
        let response = AIResponse(
            id: "r7",
            model: "model",
            content: [.text("Done")],
            usage: TokenUsage(inputTokens: 5, outputTokens: 3),
            stopReason: .endTurn
        )

        // When
        let result = response.requiresToolExecution

        // Then
        #expect(result == false)
    }

    @Test("requiresToolExecution is false when stopReason is maxTokens")
    func requiresToolExecution_maxTokensStop_returnsFalse() {
        // Given
        let response = AIResponse(
            id: "r8",
            model: "model",
            content: [.text("Truncated")],
            usage: TokenUsage(inputTokens: 5, outputTokens: 3),
            stopReason: .maxTokens
        )

        // When
        let result = response.requiresToolExecution

        // Then
        #expect(result == false)
    }
}
