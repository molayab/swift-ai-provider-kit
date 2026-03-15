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

    func decodeStreamChunk(_ data: Data) throws(AIError) -> OpenAIChatChunk {
        do {
            return try JSONDecoder().decode(OpenAIChatChunk.self, from: data)
        } catch {
            throw AIError.decodingFailed(underlying: error)
        }
    }

    func mapStreamEvent(_ data: Data) throws(AIError) -> AIStreamEvent? {
        let chunk = try decodeStreamChunk(data)

        guard let choice = chunk.choices.first else { return nil }
        let delta = choice.delta

        if let text = delta.content, !text.isEmpty {
            return .textDelta(text)
        }

        if let toolCallDeltas = delta.toolCalls, let first = toolCallDeltas.first {
            let id = first.id ?? ""
            let name = first.function?.name ?? ""
            let argsDelta = first.function?.arguments ?? ""

            // Only yield when id or name is present — this is the first (identification)
            // chunk for this tool call. Subsequent argument-only chunks have neither id
            // nor name; a stateless per-chunk mapper cannot correlate them, so they are
            // dropped here. Use OpenAIProvider.stream(_:) for correct multi-chunk
            // accumulation keyed by tool-call index.
            guard !id.isEmpty || !name.isEmpty else { return nil }
            return .toolUseDelta(id: id, name: name, inputDelta: argsDelta)
        }

        return nil
    }

    // MARK: - Private

    private func mapUsage(_ usage: OpenAIUsage) -> TokenUsage {
        TokenUsage(inputTokens: usage.promptTokens, outputTokens: usage.completionTokens)
    }

    func mapFinishReason(_ raw: String?) -> StopReason {
        switch raw {
        case "stop":           return .endTurn
        case "length":         return .maxTokens
        case "tool_calls":     return .toolUse
        case "content_filter": return .unknown
        default:               return .unknown
        }
    }

    /// Decodes a JSON-encoded arguments string (from OpenAI tool_calls) into `JSONValue`.
    private func decodeArguments(_ jsonString: String) -> JSONValue {
        guard let data = jsonString.data(using: .utf8),
              let value = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return .object([:])
        }
        return value
    }
}
