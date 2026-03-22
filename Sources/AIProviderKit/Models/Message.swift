/// A single message in a conversation turn.
public struct Message: Sendable, Equatable, Codable {

    public enum Role: String, Sendable, Equatable, Codable {
        case user
        case assistant
        case system
    }

    public let role: Role
    public let content: [ContentBlock]

    public init(role: Role, content: [ContentBlock]) {
        self.role = role
        self.content = content
    }

    /// Convenience initialiser for single-text messages.
    public init(role: Role, text: String) {
        self.role = role
        self.content = [.text(text)]
    }
}

// MARK: - Factory helpers

public extension Message {
    static func user(text: String) -> Message {
        Message(role: .user, text: text)
    }

    static func assistant(text: String) -> Message {
        Message(role: .assistant, text: text)
    }

    static func system(_ text: String) -> Message {
        Message(role: .system, text: text)
    }

    /// Build a user message with multiple content blocks.
    static func user(@ContentBlockBuilder content: () -> [ContentBlock]) -> Message {
        Message(role: .user, content: content())
    }

    /// Build an assistant message with multiple content blocks.
    static func assistant(@ContentBlockBuilder content: () -> [ContentBlock]) -> Message {
        Message(role: .assistant, content: content())
    }
}

// MARK: - Convenience

public extension Message {
    /// Returns the concatenated text from all `.text` content blocks.
    var text: String {
        content.compactMap(\.textValue).joined()
    }
}
