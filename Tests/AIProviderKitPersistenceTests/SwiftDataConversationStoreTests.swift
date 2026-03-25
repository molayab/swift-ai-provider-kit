@testable import AIProviderKit
@testable import AIProviderKitPersistence
import Foundation
import SwiftData
import Testing

@Suite("SwiftDataConversationStore")
struct SwiftDataConversationStoreTests {

    // MARK: - Helpers

    private func makeStore() throws -> SwiftDataConversationStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ConversationRecord.self, ConversationTurnRecord.self,
            configurations: config
        )
        return SwiftDataConversationStore(modelContainer: container)
    }

    // MARK: - Create

    @Test("createConversation stores and returns a new conversation")
    func createConversation_storesConversation() async throws {
        // Given
        let store = try makeStore()

        // When
        let conv = try await store.createConversation(title: "Test", model: "mock-model")

        // Then
        #expect(conv.title == "Test")
        #expect(conv.model.identifier == "mock-model")
        #expect(conv.turns.isEmpty)
        #expect(!conv.isArchived)
    }

    @Test("createConversation persists to the database")
    func createConversation_persists() async throws {
        // Given
        let store = try makeStore()

        // When
        let conv = try await store.createConversation(title: "Persisted", model: "m")
        let fetched = try await store.conversation(byId: conv.id)

        // Then
        #expect(fetched != nil)
        #expect(fetched?.title == "Persisted")
    }

    // MARK: - Read

    @Test("conversation(byId:) returns nil for unknown ID")
    func conversationById_returnsNilForUnknown() async throws {
        // Given
        let store = try makeStore()

        // When
        let result = try await store.conversation(byId: UUID())

        // Then
        #expect(result == nil)
    }

    // MARK: - allConversations

    @Test("allConversations returns all stored conversations newest first")
    func allConversations_returnsNewestFirst() async throws {
        // Given
        let store = try makeStore()
        let first = try await store.createConversation(title: "First", model: "m")
        let second = try await store.createConversation(title: "Second", model: "m")
        let third = try await store.createConversation(title: "Third", model: "m")

        // When
        let all = try await store.allConversations()

        // Then — newest first
        #expect(all.count == 3)
        #expect(all.map(\.id) == [third.id, second.id, first.id])
    }

    // MARK: - Save

    @Test("save persists turn updates")
    func save_persistsTurnUpdates() async throws {
        // Given
        let store = try makeStore()
        var conv = try await store.createConversation(title: "Save test", model: "m")
        let turn = ConversationTurn(message: .user(text: "Hello"))
        conv.turns.append(turn)

        // When
        try await store.save(conv)
        let fetched = try await store.conversation(byId: conv.id)

        // Then
        #expect(fetched?.turns.count == 1)
        #expect(fetched?.turns.first?.message.text == "Hello")
    }

    @Test("save throws conversationNotFound for unknown conversation")
    func save_throwsForUnknown() async throws {
        // Given
        let store = try makeStore()
        let unknown = Conversation(title: "Ghost", model: "m")

        // When / Then
        await #expect(throws: AIError.self) {
            try await store.save(unknown)
        }
    }

    @Test("save updates title")
    func save_updatesTitle() async throws {
        // Given
        let store = try makeStore()
        var conv = try await store.createConversation(title: "Old Title", model: "m")
        conv.title = "New Title"

        // When
        try await store.save(conv)
        let fetched = try await store.conversation(byId: conv.id)

        // Then
        #expect(fetched?.title == "New Title")
    }

    // MARK: - Delete

    @Test("delete removes the conversation")
    func delete_removesConversation() async throws {
        // Given
        let store = try makeStore()
        let conv = try await store.createConversation(title: "Delete me", model: "m")

        // When
        try await store.delete(conv)
        let all = try await store.allConversations()

        // Then
        #expect(all.isEmpty)
    }

    @Test("delete is no-op for unknown conversation")
    func delete_noOpForUnknown() async throws {
        // Given
        let store = try makeStore()
        let unknown = Conversation(title: "Ghost", model: "m")

        // When / Then — should not throw
        try await store.delete(unknown)
    }

    // MARK: - Archive

    @Test("archive sets archivedAt")
    func archive_setsArchivedAt() async throws {
        // Given
        let store = try makeStore()
        let conv = try await store.createConversation(title: "Archive me", model: "m")

        // When
        try await store.archive(conv)
        let fetched = try await store.conversation(byId: conv.id)

        // Then
        #expect(fetched?.isArchived == true)
        #expect(fetched?.archivedAt != nil)
    }

    @Test("archive throws conversationNotFound for unknown conversation")
    func archive_throwsForUnknown() async throws {
        // Given
        let store = try makeStore()
        let unknown = Conversation(title: "Ghost", model: "m")

        // When / Then
        await #expect(throws: AIError.self) {
            try await store.archive(unknown)
        }
    }

    // MARK: - Turn round-trip

    @Test("turns with token usage round-trip correctly")
    func turnsWithTokenUsage_roundTrip() async throws {
        // Given
        let store = try makeStore()
        var conv = try await store.createConversation(title: "Tokens", model: "m")
        let turn = ConversationTurn(
            message: .user(text: "Hi"),
            tokenUsage: TokenUsage(inputTokens: 10, outputTokens: 20)
        )
        conv.turns.append(turn)

        // When
        try await store.save(conv)
        let fetched = try await store.conversation(byId: conv.id)

        // Then
        let fetchedTurn = try #require(fetched?.turns.first)
        #expect(fetchedTurn.tokenUsage?.inputTokens == 10)
        #expect(fetchedTurn.tokenUsage?.outputTokens == 20)
    }
}
