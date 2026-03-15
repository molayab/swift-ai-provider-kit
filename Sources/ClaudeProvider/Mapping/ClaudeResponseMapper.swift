import AIProviderKit
import Foundation

struct ClaudeResponseMapper: Sendable {

    // MARK: - Non-streaming

    func map(_ response: ClaudeResponse) -> AIResponse {
        AIResponse(
            id: response.id,
            model: response.model,
            content: response.content.compactMap(mapContentBlock),
            usage: TokenUsage(
                inputTokens: response.usage.inputTokens,
                outputTokens: response.usage.outputTokens
            ),
            stopReason: mapStopReason(response.stopReason)
        )
    }

    // MARK: - Streaming — stateless single-chunk

    func decodeStreamEvent(_ data: Data) throws(AIError) -> ClaudeStreamEvent {
        do {
            return try JSONDecoder().decode(ClaudeStreamEvent.self, from: data)
        } catch {
            throw AIError.decodingFailed(underlying: error)
        }
    }

    /// Maps a single SSE data payload to zero or more stream events.
    ///
    /// This is a **stateless** operation: tool-call input deltas (`input_json_delta`) are
    /// dropped because there is no accumulator to correlate them across chunks. Use
    /// `makeStreamState`, `processStreamEvent`, and `finalizeStream` for full stateful
    /// accumulation across a complete SSE stream.
    func mapStreamEvent(_ data: Data) throws(AIError) -> [AIStreamEvent] {
        let event = try decodeStreamEvent(data)
        guard event.type == "content_block_delta",
              let delta = event.delta,
              delta.type == "text_delta",
              let text = delta.text else {
            return []
        }
        return [.textDelta(text)]
    }

    // MARK: - Streaming — stateful accumulation

    /// Creates fresh stream state, seeding the model field with a fallback for messages
    /// that omit `model` from early chunks.
    func makeStreamState(fallbackModel: String) -> ClaudeStreamState {
        ClaudeStreamState(messageModel: fallbackModel)
    }

    /// Applies one decoded SSE event to `state` and returns the events to yield.
    ///
    /// All metadata extraction and delta accumulation live here so that `ClaudeProvider`
    /// is a thin HTTP orchestrator. Throws on Anthropic-reported stream errors.
    func processStreamEvent(
        _ event: ClaudeStreamEvent,
        state: inout ClaudeStreamState
    ) throws(AIError) -> [AIStreamEvent] {
        switch event.type {
        case "message_start":
            state.messageId = event.message?.id ?? state.messageId
            state.messageModel = event.message?.model ?? state.messageModel
            state.inputTokens = event.message?.usage?.inputTokens ?? 0

        case "content_block_start":
            if let block = event.contentBlock, block.type == "tool_use",
               let index = event.index, let id = block.id, let name = block.name {
                state.toolAccumulators[index] = ClaudeToolAccumulator(id: id, name: name, json: "")
            }

        case "content_block_delta":
            return applyContentBlockDelta(event, state: &state)

        case "message_delta":
            state.stopReason = mapStopReason(event.delta?.stopReason)
            state.outputTokens = event.usage?.outputTokens ?? 0

        case "error":
            throw AIError.invalidResponse(statusCode: 529, body: "Anthropic stream error")

        default:
            break
        }
        return []
    }

    /// Builds the final `AIResponse` from accumulated stream state.
    func finalizeStream(_ state: ClaudeStreamState) -> AIResponse {
        var content: [ContentBlock] = []

        if !state.textBuffer.isEmpty {
            content.append(.text(state.textBuffer))
        }

        for index in state.toolAccumulators.keys.sorted() {
            guard let acc = state.toolAccumulators[index] else { continue }
            let inputData = acc.json.data(using: .utf8) ?? Data()
            let input = (try? JSONDecoder().decode(JSONValue.self, from: inputData)) ?? .object([:])
            content.append(.toolUse(.init(id: acc.id, name: acc.name, input: input)))
        }

        return AIResponse(
            id: state.messageId,
            model: state.messageModel,
            content: content,
            usage: TokenUsage(inputTokens: state.inputTokens, outputTokens: state.outputTokens),
            stopReason: state.stopReason
        )
    }

    // MARK: - Shared helpers

    func mapStopReason(_ raw: String?) -> StopReason {
        switch raw {
        case "end_turn": return .endTurn
        case "max_tokens": return .maxTokens
        case "stop_sequence": return .stopSequence
        case "tool_use": return .toolUse
        default: return .unknown
        }
    }

    // MARK: - Private

    private func mapContentBlock(_ block: ClaudeContentBlock) -> ContentBlock? {
        switch block.type {
        case "text":
            guard let text = block.text else { return nil }
            return .text(text)
        case "tool_use":
            guard let id = block.id, let name = block.name, let input = block.input else { return nil }
            return .toolUse(.init(id: id, name: name, input: input))
        default:
            return nil
        }
    }

    private func applyContentBlockDelta(
        _ event: ClaudeStreamEvent,
        state: inout ClaudeStreamState
    ) -> [AIStreamEvent] {
        guard let delta = event.delta, let index = event.index else { return [] }

        if delta.type == "text_delta", let text = delta.text {
            state.textBuffer += text
            return [.textDelta(text)]
        }

        if delta.type == "input_json_delta", let partial = delta.partialJson {
            var acc = state.toolAccumulators[index] ?? ClaudeToolAccumulator(id: "", name: "", json: "")
            acc.json += partial
            state.toolAccumulators[index] = acc
            return [.toolUseDelta(id: acc.id, name: acc.name, inputDelta: partial)]
        }

        return []
    }
}

// MARK: - Stream state

/// Mutable accumulator for a single Claude SSE stream session.
///
/// Owned by the caller (typically `ClaudeProvider.stream(_:)`) and passed into
/// `ClaudeResponseMapper.processStreamEvent(_:state:)` on every event. The mapper
/// itself remains stateless.
struct ClaudeStreamState {
    var messageId: String = ""
    var messageModel: String
    var stopReason: StopReason = .unknown
    var textBuffer: String = ""
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var toolAccumulators: [Int: ClaudeToolAccumulator] = [:]
}

// MARK: - Tool accumulator

struct ClaudeToolAccumulator {
    var id: String
    var name: String
    var json: String
}
