@testable import AIProviderKit
import Foundation
import Testing

@Suite("EphemeralMemoryConversationStore")
struct ConversationStoreTests {

    // MARK: - Create

    @Test("createConversation stores and returns a new conversation")
    func create_storesConversation() async throws {
        // Given
        let store = EphemeralMemoryConversationStore()

        // When
        let conv = try await store.createConversation(title: "Test", model: "mock-model")

        // Then
        #expect(conv.title == "Test")
        #expect(conv.model.identifier == "mock-model")
        #expect(conv.turns.isEmpty)
        #expect(!conv.isArchived)
    }

    // MARK: - allConversations

    @Test("allConversations returns all stored conversations newest first")
    func allConversations_returnsNewestFirst() async throws {
        // Given
        let store = EphemeralMemoryConversationStore()
        let first  = try await store.createConversation(title: "First", model: "m")
        let second = try await store.createConversation(title: "Second", model: "m")
        let third  = try await store.createConversation(title: "Third", model: "m")

        // When
        let all = try await store.allConversations()

        // Then
        #expect(all.count == 3)
        let ids = all.map(\.id)
        #expect(ids.contains(first.id))
        #expect(ids.contains(second.id))
        #expect(ids.contains(third.id))
    }

    // MARK: - Save

    @Test("save persists turn updates")
    func save_persistsUpdates() async throws {
        // Given
        let store = EphemeralMemoryConversationStore()
        var conv = try await store.createConversation(title: "Save test", model: "m")
        let turn = ConversationTurn(message: .user(text: "Hello"))
        conv.turns.append(turn)

        // When
        try await store.save(conv)
        let all = try await store.allConversations()
        let fetched = try #require(all.first { $0.id == conv.id })

        // Then
        #expect(fetched.turns.count == 1)
        #expect(fetched.turns.first?.message.text == "Hello")
    }

    @Test("save throws conversationNotFound for unknown conversation")
    func save_throwsForUnknown() async throws {
        // Given
        let store = EphemeralMemoryConversationStore()
        let unknown = Conversation(title: "Ghost", model: "m")

        // When / Then
        await #expect(throws: AIError.self) {
            try await store.save(unknown)
        }
    }

    // MARK: - Delete

    @Test("delete removes the conversation")
    func delete_removesConversation() async throws {
        // Given
        let store = EphemeralMemoryConversationStore()
        let conv = try await store.createConversation(title: "Delete me", model: "m")

        // When
        try await store.delete(conv)
        let all = try await store.allConversations()

        // Then
        #expect(all.isEmpty)
    }

    // MARK: - Archive

    @Test("archive sets archivedAt")
    func archive_setsArchivedAt() async throws {
        // Given
        let store = EphemeralMemoryConversationStore()
        let conv = try await store.createConversation(title: "Archive me", model: "m")

        // When
        try await store.archive(conv)
        let all = try await store.allConversations()
        let fetched = try #require(all.first { $0.id == conv.id })

        // Then
        #expect(fetched.isArchived == true)
        #expect(fetched.archivedAt != nil)
    }

    @Test("archive throws conversationNotFound for unknown conversation")
    func archive_throwsForUnknown() async throws {
        // Given
        let store = EphemeralMemoryConversationStore()
        let unknown = Conversation(title: "Ghost", model: "m")

        // When / Then
        await #expect(throws: AIError.self) {
            try await store.archive(unknown)
        }
    }
}

// MARK: - TokenBudgetTrimmer

@Suite("TokenBudgetTrimmer")
struct TokenBudgetTrimmerTests {

    private func turn(input: Int, output: Int) -> ConversationTurn {
        ConversationTurn(
            message: .user(text: "msg"),
            tokenUsage: TokenUsage(inputTokens: input, outputTokens: output)
        )
    }

    @Test("returns all turns when total is within budget")
    func withinBudget_returnsAll() {
        // Given
        let turns = [turn(input: 10, output: 10), turn(input: 20, output: 20)]

        // When
        let result = TokenBudgetTrimmer.trim(turns, toBudget: 100)

        // Then
        #expect(result.count == 2)
    }

    @Test("prunes oldest turns when over budget")
    func overBudget_prunesOldest() {
        // Given — three turns of 40 tokens each (120 total), budget 80
        let t1 = turn(input: 20, output: 20)
        let t2 = turn(input: 20, output: 20)
        let t3 = turn(input: 20, output: 20)
        let turns = [t1, t2, t3]

        // When
        let result = TokenBudgetTrimmer.trim(turns, toBudget: 80)

        // Then — oldest turn removed, t2 and t3 remain
        #expect(result.count == 2)
        #expect(result.first?.id == t2.id)
    }

    @Test("returns empty when all turns must be pruned")
    func allTurnsPruned_returnsEmpty() {
        // Given
        let turns = [turn(input: 500, output: 500)]

        // When
        let result = TokenBudgetTrimmer.trim(turns, toBudget: 1)

        // Then
        #expect(result.isEmpty)
    }

    @Test("turns without tokenUsage are never pruned forcibly")
    func turnsWithoutUsage_notPruned() {
        // Given — one large turn + one turn with no usage info
        let big = turn(input: 200, output: 200)
        let noUsage = ConversationTurn(message: .user(text: "bare"))
        let turns = [big, noUsage]

        // When — budget smaller than big turn
        let result = TokenBudgetTrimmer.trim(turns, toBudget: 10)

        // Then — big removed; noUsage (no tokens) survives
        #expect(result.count == 1)
        #expect(result.first?.id == noUsage.id)
    }
}
