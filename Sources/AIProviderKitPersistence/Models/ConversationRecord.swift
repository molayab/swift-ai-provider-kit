import AIProviderKit
import Foundation
import SwiftData

/// SwiftData model that persists a ``Conversation``.
///
/// The model identifier is stored as a plain `String` and mapped to/from
/// ``AIModel`` at the boundary via ``toConversation()`` and ``from(_:)``.
@Model
public final class ConversationRecord {

    @Attribute(.unique)
    public var id: UUID

    public var title: String
    public var modelIdentifier: String
    public var createdAt: Date
    public var archivedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ConversationTurnRecord.conversation)
    public var turns: [ConversationTurnRecord]

    public init(
        id: UUID,
        title: String,
        modelIdentifier: String,
        createdAt: Date,
        archivedAt: Date? = nil,
        turns: [ConversationTurnRecord] = []
    ) {
        self.id = id
        self.title = title
        self.modelIdentifier = modelIdentifier
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.turns = turns
    }
}

// MARK: - Mapping

extension ConversationRecord {

    /// Converts this record into a ``Conversation`` value type.
    ///
    /// - Throws: ``AIError/decodingFailed(underlying:)`` if any turn's message payload cannot be decoded.
    func toConversation() throws -> Conversation {
        let mappedTurns = try turns
            .sorted { $0.createdAt < $1.createdAt }
            .map { try $0.toConversationTurn() }

        return Conversation(
            id: id,
            title: title,
            model: AIModel(modelIdentifier),
            createdAt: createdAt,
            archivedAt: archivedAt,
            turns: mappedTurns
        )
    }

    /// Creates a new record from a ``Conversation`` value type.
    static func from(_ conversation: Conversation) throws -> ConversationRecord {
        let record = ConversationRecord(
            id: conversation.id,
            title: conversation.title,
            modelIdentifier: conversation.model.identifier,
            createdAt: conversation.createdAt,
            archivedAt: conversation.archivedAt
        )
        record.turns = try conversation.turns.map {
            try ConversationTurnRecord.from($0, conversation: record)
        }
        return record
    }
}
