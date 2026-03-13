import Foundation
import AIProviderKit

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

        return AIResponse(
            id: UUID().uuidString,
            model: model,
            content: content,
            usage: TokenUsage(inputTokens: 0, outputTokens: 0),
            stopReason: mapStopReason(response.stopReason)
        )
    }

    func mapStreamDelta(_ delta: FMStreamDelta) -> AIStreamEvent {
        .textDelta(delta.text)
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
