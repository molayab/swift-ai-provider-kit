import AIProviderKit
import Foundation

struct ClaudeResponseMapper: Sendable {

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

    func mapStreamEvent(_ data: Data) throws(AIError) -> AIStreamEvent? {
        let event: ClaudeStreamEvent
        do {
            event = try JSONDecoder().decode(ClaudeStreamEvent.self, from: data)
        } catch {
            throw AIError.decodingFailed(underlying: error)
        }
        guard event.type == "content_block_delta",
              let delta = event.delta,
              delta.type == "text_delta",
              let text = delta.text else {
            return nil
        }
        return .textDelta(text)
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

    private func mapStopReason(_ raw: String?) -> StopReason {
        switch raw {
        case "end_turn":      return .endTurn
        case "max_tokens":    return .maxTokens
        case "stop_sequence": return .stopSequence
        case "tool_use":      return .toolUse
        default:              return .unknown
        }
    }
}
