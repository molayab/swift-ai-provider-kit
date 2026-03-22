import Foundation

/// A single piece of content within a message.
///
/// Maps to both Claude's content blocks and OpenAI's message content parts,
/// enabling provider-agnostic conversation building.
public enum ContentBlock: Sendable, Equatable {

    /// Plain text.
    case text(String)

    /// An image attached to a message.
    case image(ImageContent)

    /// A tool call emitted by the model.
    case toolUse(ToolUseContent)

    /// The result of executing a tool, sent back to the model.
    case toolResult(ToolResultContent)

    // MARK: - Nested Types

    public struct ImageContent: Sendable, Equatable {
        public enum Source: Sendable, Equatable {
            case base64(mediaType: String, data: Data)
            case url(String)
        }

        public let source: Source

        public init(source: Source) {
            self.source = source
        }
    }

    public struct ToolUseContent: Sendable, Equatable {
        public let id: String
        public let name: String
        public let input: JSONValue

        public init(id: String, name: String, input: JSONValue) {
            self.id = id
            self.name = name
            self.input = input
        }
    }

    public struct ToolResultContent: Sendable, Equatable {
        public let toolUseId: String
        public let content: [ContentBlock]
        public let isError: Bool

        public init(toolUseId: String, content: [ContentBlock], isError: Bool = false) {
            self.toolUseId = toolUseId
            self.content = content
            self.isError = isError
        }
    }
}

// MARK: - Convenience

public extension ContentBlock {
    /// Extracts the text string if this block is `.text`.
    var textValue: String? {
        guard case .text(let value) = self else { return nil }
        return value
    }
}

// MARK: - Codable

extension ContentBlock: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, text, source, id, name, input, toolUseId, content, isError
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "image":
            self = .image(try container.decode(ImageContent.self, forKey: .source))
        case "tool_use":
            self = .toolUse(ToolUseContent(
                id: try container.decode(String.self, forKey: .id),
                name: try container.decode(String.self, forKey: .name),
                input: try container.decode(JSONValue.self, forKey: .input)
            ))
        case "tool_result":
            self = .toolResult(ToolResultContent(
                toolUseId: try container.decode(String.self, forKey: .toolUseId),
                content: try container.decode([ContentBlock].self, forKey: .content),
                isError: try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
            ))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown ContentBlock type: \(type)"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let image):
            try container.encode("image", forKey: .type)
            try container.encode(image, forKey: .source)
        case .toolUse(let use):
            try container.encode("tool_use", forKey: .type)
            try container.encode(use.id, forKey: .id)
            try container.encode(use.name, forKey: .name)
            try container.encode(use.input, forKey: .input)
        case .toolResult(let result):
            try container.encode("tool_result", forKey: .type)
            try container.encode(result.toolUseId, forKey: .toolUseId)
            try container.encode(result.content, forKey: .content)
            try container.encode(result.isError, forKey: .isError)
        }
    }
}

extension ContentBlock.ImageContent: Codable {
    private enum CodingKeys: String, CodingKey { case type, mediaType, data, url }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "base64":
            let mediaType = try container.decode(String.self, forKey: .mediaType)
            let b64String = try container.decode(String.self, forKey: .data)
            guard let data = Data(base64Encoded: b64String) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .data,
                    in: container,
                    debugDescription: "Invalid base64 data"
                )
            }
            self.init(source: .base64(mediaType: mediaType, data: data))
        case "url":
            self.init(source: .url(try container.decode(String.self, forKey: .url)))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown image source type: \(type)"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch source {
        case .base64(let mediaType, let data):
            try container.encode("base64", forKey: .type)
            try container.encode(mediaType, forKey: .mediaType)
            try container.encode(data.base64EncodedString(), forKey: .data)
        case .url(let url):
            try container.encode("url", forKey: .type)
            try container.encode(url, forKey: .url)
        }
    }
}
