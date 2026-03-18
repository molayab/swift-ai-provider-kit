import Foundation

/// A zero-dependency, in-memory ``ConversationStore``.
///
/// All state lives in the actor's isolated dictionary and is discarded when the
/// actor is deallocated. This is the backing type for
/// ``SupportedConversationStore/ephemeralMemory``.
actor EphemeralMemoryConversationStore: ConversationStore {

    private var store: [UUID: Conversation] = [:]

    // MARK: - ConversationStore

    @discardableResult
    func createConversation(title: String, model: AIModel) async throws -> Conversation {
        let conversation = Conversation(title: title, model: model)
        store[conversation.id] = conversation
        return conversation
    }

    func conversation(byId id: UUID) async throws -> Conversation? {
        store[id]
    }

    func allConversations() async throws -> [Conversation] {
        store.values.sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ conversation: Conversation) async throws {
        guard store[conversation.id] != nil else {
            throw AIError.conversationNotFound(conversation.id.uuidString)
        }
        store[conversation.id] = conversation
    }

    func delete(_ conversation: Conversation) async throws {
        store.removeValue(forKey: conversation.id)
    }

    func archive(_ conversation: Conversation) async throws {
        guard var stored = store[conversation.id] else {
            throw AIError.conversationNotFound(conversation.id.uuidString)
        }
        stored.archivedAt = Date()
        store[conversation.id] = stored
    }
}
