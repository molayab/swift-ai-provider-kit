import AIProviderKit
import Foundation

struct ClaudeRequestMapper: Sendable {

    func map(_ request: AIRequest, stream: Bool) -> ClaudeRequest {
        ClaudeRequest(
            model: request.model.identifier,
            maxTokens: request.maxTokens,
            system: request.systemPrompt,
            messages: request.messages
                .filter { $0.role != .system }
                .map(mapMessage),
            tools: request.tools.isEmpty ? nil : request.tools.map(mapTool),
            temperature: request.temperature,
            topP: request.topP,
            stopSequences: request.stopSequences.isEmpty ? nil : request.stopSequences,
            stream: stream
        )
    }

    // MARK: - Private

    private func mapMessage(_ message: Message) -> ClaudeMessage {
        ClaudeMessage(role: message.role.rawValue, content: message.content.map(mapContentBlock))
    }

    private func mapContentBlock(_ block: ContentBlock) -> ClaudeContentBlock {
        switch block {
        case .text(let text):
            return ClaudeContentBlock(
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

        case .image(let image):
            return ClaudeContentBlock(
                type: "image",
                text: nil,
                source: mapImageSource(image.source),
                id: nil,
                name: nil,
                input: nil,
                toolUseId: nil,
                content: nil,
                isError: nil
            )

        case .toolUse(let use):
            return ClaudeContentBlock(
                type: "tool_use",
                text: nil,
                source: nil,
                id: use.id,
                name: use.name,
                input: use.input,
                toolUseId: nil,
                content: nil,
                isError: nil
            )

        case .toolResult(let result):
            return ClaudeContentBlock(
                type: "tool_result",
                text: nil,
                source: nil,
                id: nil,
                name: nil,
                input: nil,
                toolUseId: result.toolUseId,
                content: result.content.map(mapContentBlock),
                isError: result.isError ? true : nil
            )
        }
    }

    private func mapImageSource(_ source: ContentBlock.ImageContent.Source) -> ClaudeImageSource {
        switch source {
        case .base64(let mediaType, let data):
            return ClaudeImageSource(type: "base64", mediaType: mediaType, data: data.base64EncodedString(), url: nil)
        case .url(let urlString):
            return ClaudeImageSource(type: "url", mediaType: nil, data: nil, url: urlString)
        }
    }

    private func mapTool(_ tool: Tool) -> ClaudeTool {
        ClaudeTool(name: tool.name, description: tool.description, inputSchema: tool.inputSchema)
    }
}
