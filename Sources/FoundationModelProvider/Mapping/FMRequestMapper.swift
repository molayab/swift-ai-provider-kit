import Foundation
import AIProviderKit

/// Maps an `AIRequest` to the internal `FMRequest` representation.
///
/// Converts messages, system prompts, tools, and sampling parameters into
/// the format expected by `FMSessionProtocol.respond(to:)` and `stream(_:)`.
struct FMRequestMapper: Sendable {

    func map(_ request: AIRequest) -> FMRequest {
        FMRequest(
            systemPrompt: request.systemPrompt,
            messages: request.messages
                .filter { $0.role != .system }
                .map(mapMessage),
            tools: request.tools.map(mapTool),
            maxTokens: request.maxTokens,
            temperature: request.temperature
        )
    }

    // MARK: - Private

    private func mapMessage(_ message: Message) -> FMMessage {
        let content = message.content.compactMap(mapContentBlock).joined(separator: "\n")
        return FMMessage(role: message.role.rawValue, content: content)
    }

    private func mapContentBlock(_ block: ContentBlock) -> String? {
        switch block {
        case .text(let text):
            return text
        case .image:
            // Vision not supported in the initial Foundation Models integration;
            // image blocks are silently dropped.
            return nil
        case .toolUse(let use):
            return "[Tool call requested: \(use.name)]"
        case .toolResult(let result):
            let resultText = result.content.compactMap(\.textValue).joined()
            return "[Tool result for id=\(result.toolUseId): \(resultText)]"
        }
    }

    private func mapTool(_ tool: Tool) -> FMToolDefinition {
        let schemaJSON = (try? JSONEncoder().encode(tool.inputSchema))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return FMToolDefinition(
            name: tool.name,
            description: tool.description,
            parametersSchemaJSON: schemaJSON,
            handler: tool.execute(with:)
        )
    }
}
