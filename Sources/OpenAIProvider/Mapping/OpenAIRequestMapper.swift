import AIProviderKit
import Foundation

/// Maps a provider-agnostic `AIRequest` to the OpenAI Chat Completions wire format.
///
/// Key differences from Claude:
/// - System prompts are injected as the first message with `role: "system"`.
/// - Tool results are sent as individual `role: "tool"` messages (not content blocks).
/// - Assistant tool calls use `tool_calls` array instead of `tool_use` content blocks.
/// - Images use the `image_url` content part format.
struct OpenAIRequestMapper: Sendable {

    func map(_ request: AIRequest, stream: Bool) -> OpenAIChatRequest {
        var messages: [OpenAIMessage] = []

        if let systemPrompt = request.systemPrompt {
            messages.append(OpenAIMessage(
                role: "system",
                content: .text(systemPrompt),
                toolCalls: nil,
                toolCallId: nil
            ))
        }

        for message in request.messages where message.role != .system {
            messages.append(contentsOf: mapMessage(message))
        }

        return OpenAIChatRequest(
            model: request.model.identifier,
            messages: messages,
            tools: request.tools.isEmpty ? nil : request.tools.map(mapTool),
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            topP: request.topP,
            stop: request.stopSequences.isEmpty ? nil : request.stopSequences,
            stream: stream
        )
    }

    // MARK: - Private

    private func mapMessage(_ message: Message) -> [OpenAIMessage] {
        switch message.role {
        case .user:
            return mapUserMessage(message)
        case .assistant:
            return [mapAssistantMessage(message)]
        case .system:
            return []
        }
    }

    /// Maps a user-role `Message` to OpenAI messages.
    ///
    /// If the message contains `toolResult` blocks (injected by `AIClient` after
    /// tool execution), each result becomes a separate `role: "tool"` message.
    /// Otherwise, the message is sent as a regular user message.
    private func mapUserMessage(_ message: Message) -> [OpenAIMessage] {
        let toolResultMessages: [OpenAIMessage] = message.content.compactMap { block in
            guard case .toolResult(let result) = block else { return nil }
            let content = result.content.compactMap { inner -> String? in
                if case .text(let text) = inner { return text }
                return nil
            }.joined()
            return OpenAIMessage(
                role: "tool",
                content: .text(content),
                toolCalls: nil,
                toolCallId: result.toolUseId
            )
        }

        if !toolResultMessages.isEmpty {
            return toolResultMessages
        }

        let nonToolBlocks = message.content.filter {
            if case .toolResult = $0 { return false }
            return true
        }

        let parts = nonToolBlocks.compactMap(mapContentPart)

        if parts.count == 1, case .text(let text) = nonToolBlocks.first {
            return [OpenAIMessage(role: "user", content: .text(text), toolCalls: nil, toolCallId: nil)]
        }

        return [OpenAIMessage(role: "user", content: .parts(parts), toolCalls: nil, toolCallId: nil)]
    }

    /// Maps an assistant-role `Message` to an OpenAI assistant message.
    ///
    /// `toolUse` content blocks are converted to the `tool_calls` array.
    /// Text and tool use can coexist in the same message.
    private func mapAssistantMessage(_ message: Message) -> OpenAIMessage {
        var textContent: String?
        var toolCalls: [OpenAIToolCall] = []

        for block in message.content {
            switch block {
            case .text(let text):
                textContent = (textContent ?? "") + text
            case .toolUse(let use):
                let argsString = encodeArguments(use.input)
                toolCalls.append(OpenAIToolCall(
                    id: use.id,
                    type: "function",
                    function: OpenAIFunctionCall(name: use.name, arguments: argsString)
                ))
            case .image, .toolResult:
                break
            }
        }

        return OpenAIMessage(
            role: "assistant",
            content: textContent.map { .text($0) },
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            toolCallId: nil
        )
    }

    private func mapContentPart(_ block: ContentBlock) -> OpenAIContentPart? {
        switch block {
        case .text(let text):
            return OpenAIContentPart(type: "text", text: text, imageUrl: nil)
        case .image(let image):
            switch image.source {
            case .url(let urlString):
                return OpenAIContentPart(
                    type: "image_url",
                    text: nil,
                    imageUrl: OpenAIImageURL(url: urlString)
                )
            case .base64(let mediaType, let data):
                let dataURI = "data:\(mediaType);base64,\(data.base64EncodedString())"
                return OpenAIContentPart(
                    type: "image_url",
                    text: nil,
                    imageUrl: OpenAIImageURL(url: dataURI)
                )
            }
        case .toolUse, .toolResult:
            return nil
        }
    }

    private func mapTool(_ tool: Tool) -> OpenAITool {
        OpenAITool(
            type: "function",
            function: OpenAIFunction(
                name: tool.name,
                description: tool.description,
                parameters: JSONSchemaWrapper(tool.inputSchema)
            )
        )
    }

    private func encodeArguments(_ value: JSONValue) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
