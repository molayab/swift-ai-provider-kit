import Foundation

/// A single turn in a conversation, pairing a message with its metadata.
public struct ConversationTurn: Sendable, Identifiable, Codable, Equatable {
    public let id: UUID
    /// The message sent or received during this turn.
    public let message: Message
    /// When this turn was created.
    public let createdAt: Date
    /// Token usage reported by the provider for this turn, if available.
    public let tokenUsage: TokenUsage?

    public init(
        id: UUID = UUID(),
        message: Message,
        createdAt: Date = Date(),
        tokenUsage: TokenUsage? = nil
    ) {
        self.id = id
        self.message = message
        self.createdAt = createdAt
        self.tokenUsage = tokenUsage
    }
}

/// A named, model-bound sequence of conversation turns.
public struct Conversation: Sendable, Identifiable, Codable, Equatable {
    public let id: UUID
    /// Human-readable title set at creation time.
    public var title: String
    /// The model used for every turn in this conversation.
    public let model: AIModel
    /// When the conversation was created.
    public let createdAt: Date
    /// Set when the conversation is archived; `nil` while active.
    public var archivedAt: Date?
    /// Ordered list of turns, oldest first.
    public var turns: [ConversationTurn]

    public init(
        id: UUID = UUID(),
        title: String,
        model: AIModel,
        createdAt: Date = Date(),
        archivedAt: Date? = nil,
        turns: [ConversationTurn] = []
    ) {
        self.id = id
        self.title = title
        self.model = model
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.turns = turns
    }

    /// Whether this conversation is currently archived.
    public var isArchived: Bool { archivedAt != nil }

    /// The combined token usage across all turns that report it.
    public var totalTokenUsage: TokenUsage {
        turns.compactMap(\.tokenUsage).reduce(TokenUsage(inputTokens: 0, outputTokens: 0)) {
            TokenUsage(inputTokens: $0.inputTokens + $1.inputTokens,
                       outputTokens: $0.outputTokens + $1.outputTokens)
        }
    }
}
