import AIProviderKit
import Foundation

/// Maps internal `FMResponse` / `FMStreamDelta` values to the
/// provider-agnostic `AIResponse` / `AIStreamEvent` types.
struct FMResponseMapper: Sendable {

    func map(_ response: FMResponse, model: String) -> AIResponse {
        let content: [ContentBlock]

        if !response.toolCalls.isEmpty {
            content = response.toolCalls.enumerated().map { index, call in
                ContentBlock.toolUse(.init(
                    id: call.id.isEmpty ? "fm_tool_\(index)" : call.id,
                    name: call.name,
                    input: parseJSONValue(call.argumentsJSON)
                ))
            }
        } else {
            content = [.text(response.content)]
        }

        // FoundationModels does not expose token counts. Estimate output tokens
        // using the standard BPE heuristic: 1 token ≈ 4 characters.
        let estimatedOutput = max(1, response.content.utf16.count / 4)

        return AIResponse(
            id: UUID().uuidString,
            model: model,
            content: content,
            usage: TokenUsage(inputTokens: 0, outputTokens: estimatedOutput),
            stopReason: mapStopReason(response.stopReason)
        )
    }

    func mapStreamDelta(_ delta: FMStreamDelta) -> AIStreamEvent {
        .textDelta(delta.text)
    }

    /// Synthesises a final `AIResponse` from the fully accumulated stream text.
    /// Called by `AppleIntelligenceProvider.stream(_:)` after all deltas have
    /// been yielded so that consumers receive a `.message` event with token estimates.
    func mapStreamFinal(_ text: String, model: String) -> AIResponse {
        let estimatedOutput = max(1, text.utf16.count / 4)
        return AIResponse(
            id: UUID().uuidString,
            model: model,
            content: [.text(text)],
            usage: TokenUsage(inputTokens: 0, outputTokens: estimatedOutput),
            stopReason: .endTurn
        )
    }

    // MARK: - Private

    private func mapStopReason(_ reason: FMStopReason) -> StopReason {
        switch reason {
        case .endTurn:    return .endTurn
        case .maxTokens:  return .maxTokens
        case .toolUse:    return .toolUse
        }
    }

    private func parseJSONValue(_ jsonString: String) -> JSONValue {
        guard
            let data = jsonString.data(using: .utf8),
            let value = try? JSONDecoder().decode(JSONValue.self, from: data)
        else {
            return .string(jsonString)
        }
        return value
    }
}
