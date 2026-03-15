import AIProviderKit
import Foundation

/// Maps OpenAI Chat Completions wire responses to the provider-agnostic `AIResponse` and `AIStreamEvent`.
///
/// Key differences from Claude:
/// - `finish_reason` values differ: `"stop"` → `.endTurn`, `"tool_calls"` → `.toolUse`.
/// - Tool calls are in a `tool_calls` array on the message, not content blocks.
/// - Tool call arguments arrive as a raw JSON string and must be decoded to `JSONValue`.
/// - Usage uses `prompt_tokens` / `completion_tokens` instead of `input_tokens` / `output_tokens`.
struct OpenAIResponseMapper: Sendable {

    // MARK: - Non-streaming

    func map(_ response: OpenAIChatResponse) -> AIResponse {
        guard let choice = response.choices.first else {
            return AIResponse(
                id: response.id,
                model: response.model,
                content: [],
                usage: mapUsage(response.usage),
                stopReason: .unknown
            )
        }

        var content: [ContentBlock] = []

        if let text = choice.message.content, !text.isEmpty {
            content.append(.text(text))
        }

        if let toolCalls = choice.message.toolCalls {
            for toolCall in toolCalls {
                content.append(.toolUse(.init(
                    id: toolCall.id,
                    name: toolCall.function.name,
                    input: decodeArguments(toolCall.function.arguments)
                )))
            }
        }

        return AIResponse(
            id: response.id,
            model: response.model,
            content: content,
            usage: mapUsage(response.usage),
            stopReason: mapFinishReason(choice.finishReason)
        )
    }

    // MARK: - Streaming — stateless single-chunk

    func decodeStreamChunk(_ data: Data) throws(AIError) -> OpenAIChatChunk {
        do {
            return try JSONDecoder().decode(OpenAIChatChunk.self, from: data)
        } catch {
            throw AIError.decodingFailed(underlying: error)
        }
    }

    /// Maps a single SSE data payload to zero or more stream events.
    ///
    /// This is a **stateless** operation: argument-only tool-call deltas (chunks that carry
    /// `arguments` but no `id` or `name`) are dropped because there is no accumulator to
    /// correlate them. Use `makeStreamState`, `processStreamChunk`, and `finalizeStream` for
    /// full, stateful accumulation across a complete SSE stream.
    func mapStreamEvent(_ data: Data) throws(AIError) -> [AIStreamEvent] {
        let chunk = try decodeStreamChunk(data)

        guard let choice = chunk.choices.first else { return [] }
        let delta = choice.delta

        if let text = delta.content, !text.isEmpty {
            return [.textDelta(text)]
        }

        if let toolCallDeltas = delta.toolCalls {
            // Iterate all tool-call deltas in this chunk — OpenAI may include multiple
            // indexed tool calls in a single SSE chunk. Only emit events for deltas that
            // carry an id or name; argument-only deltas are dropped because this stateless
            // mapper has no accumulator to correlate them. Use OpenAIProvider.stream(_:)
            // for correct multi-chunk, multi-tool accumulation keyed by index.
            return toolCallDeltas.compactMap { tc in
                let id = tc.id ?? ""
                let name = tc.function?.name ?? ""
                guard !id.isEmpty || !name.isEmpty else { return nil }
                return .toolUseDelta(id: id, name: name, inputDelta: tc.function?.arguments ?? "")
            }
        }

        return []
    }

    // MARK: - Streaming — stateful accumulation

    /// Creates fresh stream state, seeding the model field with a fallback for providers
    /// that omit `model` from early chunks.
    func makeStreamState(fallbackModel: String) -> OpenAIStreamState {
        OpenAIStreamState(messageModel: fallbackModel)
    }

    /// Applies one decoded SSE chunk to `state` and returns the events to yield.
    ///
    /// All metadata extraction (id, model, usage, stop reason) and delta accumulation
    /// live here so that `OpenAIProvider` is a thin HTTP orchestrator.
    func processStreamChunk(
        _ chunk: OpenAIChatChunk,
        state: inout OpenAIStreamState
    ) -> [AIStreamEvent] {
        if let id = chunk.id, !id.isEmpty { state.messageId = id }
        if let model = chunk.model, !model.isEmpty { state.messageModel = model }

        // Final usage-only chunk emitted when stream_options.include_usage is true.
        if let usage = chunk.usage {
            state.inputTokens = usage.promptTokens
            state.outputTokens = usage.completionTokens
        }

        guard let choice = chunk.choices.first else { return [] }

        if let reason = choice.finishReason {
            state.stopReason = mapFinishReason(reason)
        }

        var events: [AIStreamEvent] = []
        let delta = choice.delta

        if let text = delta.content, !text.isEmpty {
            state.textBuffer += text
            events.append(.textDelta(text))
        }

        if let toolCallDeltas = delta.toolCalls {
            events += applyToolCallDeltas(toolCallDeltas, into: &state.toolAccumulators)
        }

        return events
    }

    /// Builds the final `AIResponse` from accumulated stream state.
    func finalizeStream(_ state: OpenAIStreamState) -> AIResponse {
        var content: [ContentBlock] = []

        if !state.textBuffer.isEmpty {
            content.append(.text(state.textBuffer))
        }

        for index in state.toolAccumulators.keys.sorted() {
            guard let acc = state.toolAccumulators[index] else { continue }
            let inputData = acc.arguments.data(using: .utf8) ?? Data()
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

    func mapFinishReason(_ raw: String?) -> StopReason {
        switch raw {
        case "stop": return .endTurn
        case "length": return .maxTokens
        case "tool_calls": return .toolUse
        case "content_filter": return .unknown
        default: return .unknown
        }
    }

    // MARK: - Private

    private func mapUsage(_ usage: OpenAIUsage) -> TokenUsage {
        TokenUsage(inputTokens: usage.promptTokens, outputTokens: usage.completionTokens)
    }

    /// Decodes a JSON-encoded arguments string (from OpenAI tool_calls) into `JSONValue`.
    private func decodeArguments(_ jsonString: String) -> JSONValue {
        guard let data = jsonString.data(using: .utf8),
              let value = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return .object([:])
        }
        return value
    }

    /// Applies a batch of tool-call deltas to the accumulator dictionary and returns events.
    private func applyToolCallDeltas(
        _ deltas: [OpenAIChatChunk.OpenAIToolCallDelta],
        into toolAccumulators: inout [Int: OpenAIToolAccumulator]
    ) -> [AIStreamEvent] {
        var events: [AIStreamEvent] = []
        for tc in deltas {
            let idx = tc.index
            var acc = toolAccumulators[idx] ?? OpenAIToolAccumulator(id: "", name: "", arguments: "")
            if let newId = tc.id, !newId.isEmpty { acc.id = newId }
            if let newName = tc.function?.name, !newName.isEmpty { acc.name = newName }
            let argsDelta = tc.function?.arguments ?? ""
            acc.arguments += argsDelta
            toolAccumulators[idx] = acc
            if !argsDelta.isEmpty {
                events.append(.toolUseDelta(id: acc.id, name: acc.name, inputDelta: argsDelta))
            }
        }
        return events
    }
}

// MARK: - Stream state

/// Mutable accumulator for a single OpenAI SSE stream session.
///
/// Owned by the caller (typically `OpenAIProvider.stream(_:)`) and passed into
/// `OpenAIResponseMapper.processStreamChunk(_:state:)` on every chunk. The mapper
/// itself remains stateless.
struct OpenAIStreamState {
    var messageId: String = ""
    var messageModel: String
    var stopReason: StopReason = .unknown
    var textBuffer: String = ""
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var toolAccumulators: [Int: OpenAIToolAccumulator] = [:]
}

// MARK: - Tool accumulator

struct OpenAIToolAccumulator {
    var id: String
    var name: String
    var arguments: String
}
