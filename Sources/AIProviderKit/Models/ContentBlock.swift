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
