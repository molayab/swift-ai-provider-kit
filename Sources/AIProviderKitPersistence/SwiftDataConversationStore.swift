import AIProviderKit
import Foundation
import SwiftData

/// A SwiftData-backed ``ConversationStore`` implementation.
///
/// Callers inject their own ``ModelContainer`` at init time. The store creates
/// a dedicated ``ModelContext`` on a background thread via ``ModelActor`` for
/// safe concurrent access.
///
/// ```swift
/// let container = try ModelContainer(
///     for: ConversationRecord.self, ConversationTurnRecord.self
/// )
/// let store = SwiftDataConversationStore(modelContainer: container)
/// ```
@ModelActor
public actor SwiftDataConversationStore: ConversationStore {

    // MARK: - ConversationStore

    @discardableResult public func createConversation(title: String, model: AIModel) async throws -> Conversation {
        let conversation = Conversation(title: title, model: model)
        let record = try ConversationRecord.from(conversation)
        modelContext.insert(record)
        try modelContext.save()
        return conversation
    }

    public func conversation(byId id: UUID) async throws -> Conversation? {
        let descriptor = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first?.toConversation()
    }

    public func allConversations() async throws -> [Conversation] {
        let descriptor = FetchDescriptor<ConversationRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { try $0.toConversation() }
    }

    public func save(_ conversation: Conversation) async throws {
        let id = conversation.id
        let descriptor = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record = try modelContext.fetch(descriptor).first else {
            throw AIError.conversationNotFound(conversation.id.uuidString)
        }

        // Update scalar fields
        record.title = conversation.title
        record.archivedAt = conversation.archivedAt

        // Rebuild turns: delete existing, insert fresh copies
        for turn in record.turns {
            modelContext.delete(turn)
        }
        record.turns = try conversation.turns.map {
            try ConversationTurnRecord.from($0, conversation: record)
        }

        try modelContext.save()
    }

    public func delete(_ conversation: Conversation) async throws {
        let id = conversation.id
        let descriptor = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    public func archive(_ conversation: Conversation) async throws {
        let id = conversation.id
        let descriptor = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record = try modelContext.fetch(descriptor).first else {
            throw AIError.conversationNotFound(conversation.id.uuidString)
        }
        record.archivedAt = Date()
        try modelContext.save()
    }
}
