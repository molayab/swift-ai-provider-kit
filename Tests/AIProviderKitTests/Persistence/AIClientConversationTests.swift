import AIProviderKit
import Foundation
import Testing

@Suite("AIClient — Conversation API")
struct AIClientConversationTests {

    // MARK: - createConversation

    @Test("createConversation stores a conversation with the given model and title")
    func createConversation_storesCorrectly() async throws {
        // Given
        let client = AIClient(provider: MockAIProvider())

        // When
        let conv = try await client.createConversation(model: AIModel("m1"), title: "Hello")

        // Then
        #expect(conv.title == "Hello")
        #expect(conv.model.identifier == "m1")
        #expect(conv.turns.isEmpty)
    }

    @Test("createConversation accepts a ProviderModel enum case")
    func createConversation_acceptsProviderModel() async throws {
        // Given
        let client = AIClient(provider: MockAIProvider())

        // When
        let conv = try await client.createConversation(model: MockModel.v1, title: "Typed")

        // Then
        #expect(conv.model.identifier == "mock-v1")
    }

    // MARK: - send(conversation:)

    @Test("send(conversation:) appends user and assistant turns")
    func sendConversation_appendsTurns() async throws {
        // Given
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)
        let conv = try await client.createConversation(model: "mock-model", title: "Chat")

        // When
        _ = try await client.send(conversation: conv, message: "Hello")

        // Then — one user turn + one assistant turn
        let stored = try await client.conversations()
        let updated = try #require(stored.first { $0.id == conv.id })
        #expect(updated.turns.count == 2)
        #expect(updated.turns[0].message.role == .user)
        #expect(updated.turns[0].message.text == "Hello")
        #expect(updated.turns[1].message.role == .assistant)
    }

    @Test("send(conversation:) builds full history from prior turns")
    func sendConversation_includesPriorTurns() async throws {
        // Given
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)
        let conv = try await client.createConversation(model: "mock-model", title: "Multi-turn")

        // When — two sequential sends; second send gets the latest conversation from the store
        _ = try await client.send(conversation: conv, message: "First")
        let updated = try #require(try await client.conversations().first { $0.id == conv.id })
        _ = try await client.send(conversation: updated, message: "Second")

        // Then — second request includes prior messages
        let secondRequest = provider.receivedRequests[1]
        #expect(secondRequest.messages.count >= 3) // user(First) + assistant + user(Second)
    }

    @Test("send(conversation:) throws conversationNotFound for an unknown conversation")
    func sendConversation_throwsForUnknown() async throws {
        // Given
        let client = AIClient(provider: MockAIProvider())
        let ghost = Conversation(title: "Ghost", model: "m")

        // When / Then — must be conversationNotFound, not just any AIError
        await #expect {
            try await client.send(conversation: ghost, message: "Hi")
        } throws: { error in
            guard let aiError = error as? AIError, case .conversationNotFound = aiError else { return false }
            return true
        }
    }

    @Test("send(conversation:tokenBudget:) trims oldest turns before building request")
    func sendWithBudget_trimsTurns() async throws {
        // Given
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)
        let conv = try await client.createConversation(model: "mock-model", title: "Budget")

        // When — budget of 0 removes all prior turns from the request
        _ = try await client.send(conversation: conv, message: "Hi", tokenBudget: 0)

        // Then — request only contains the new user message
        let sentRequest = provider.receivedRequests.last
        #expect(sentRequest?.messages.count == 1)
    }

    // MARK: - conversation(byId:)

    @Test("conversation(byId:) returns the matching conversation")
    func conversationById_returnsMatch() async throws {
        let client = AIClient(provider: MockAIProvider())
        let conv = try await client.createConversation(model: "m", title: "Find me")

        let found = try await client.conversation(byId: conv.id)

        #expect(found?.id == conv.id)
        #expect(found?.title == "Find me")
    }

    @Test("conversation(byId:) returns nil for an unknown id")
    func conversationById_returnsNilForUnknown() async throws {
        let client = AIClient(provider: MockAIProvider())

        let result = try await client.conversation(byId: UUID())

        #expect(result == nil)
    }

    // MARK: - conversations() — resume

    @Test("conversations() returns latest stored state after send")
    func resumeConversation_returnsLatest() async throws {
        // Given — create and add a turn so the stored state differs from the original value
        let client = AIClient(provider: MockAIProvider())
        let original = try await client.createConversation(model: "mock-model", title: "Resume")
        _ = try await client.send(conversation: original, message: "First")

        // When — load the latest state via conversations()
        let latest = try #require(try await client.conversations().first { $0.id == original.id })

        // Then — latest has the turns that were added after `original` was captured
        #expect(latest.turns.count == 2)
    }

    @Test("send(conversation:) with a stale reference picks up from the latest stored turns")
    func sendStaleReference_resumesFromLatest() async throws {
        // Given — capture the conversation before any turns are added
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)
        let stale = try await client.createConversation(model: "mock-model", title: "Stale")

        // Add a turn through a separate send so `stale` is out of date
        _ = try await client.send(conversation: stale, message: "Turn 1")

        // When — send again using the stale reference
        _ = try await client.send(conversation: stale, message: "Turn 2")

        // Then — the second request includes Turn 1's messages (loaded from store)
        let secondRequest = provider.receivedRequests[1]
        #expect(secondRequest.messages.count >= 3)
    }

    // MARK: - conversations()

    @Test("conversations() returns all stored conversations")
    func conversations_returnsAll() async throws {
        // Given
        let client = AIClient(provider: MockAIProvider())
        _ = try await client.createConversation(model: "m", title: "A")
        _ = try await client.createConversation(model: "m", title: "B")

        // When
        let all = try await client.conversations()

        // Then
        #expect(all.count == 2)
    }

    // MARK: - delete(conversation:)

    @Test("delete(conversation:) removes the conversation")
    func delete_removesConversation() async throws {
        // Given
        let client = AIClient(provider: MockAIProvider())
        let conv = try await client.createConversation(model: "m", title: "Delete me")

        // When
        try await client.delete(conversation: conv)

        // Then
        let remaining = try await client.conversations()
        #expect(remaining.isEmpty)
    }

    // MARK: - archive(conversation:)

    @Test("archive(conversation:) marks the conversation as archived")
    func archive_marksAsArchived() async throws {
        // Given
        let client = AIClient(provider: MockAIProvider())
        let conv = try await client.createConversation(model: "m", title: "Archive me")

        // When
        try await client.archive(conversation: conv)

        // Then
        let all = try await client.conversations()
        let updated = try #require(all.first { $0.id == conv.id })
        #expect(updated.isArchived)
    }

    // MARK: - send(conversation:systemPrompt:)

    @Test("send(conversation:systemPrompt:) forwards the system prompt in the request")
    func sendConversation_forwardsSystemPrompt() async throws {
        // Given
        let provider = MockAIProvider()
        let client = AIClient(provider: provider)
        let conv = try await client.createConversation(model: "mock-model", title: "Sys")

        // When
        _ = try await client.send(conversation: conv, message: "Hi", systemPrompt: "Be concise.")

        // Then
        let sentRequest = try #require(provider.receivedRequests.last)
        #expect(sentRequest.systemPrompt == "Be concise.")
    }

    // MARK: - stream(conversation:)

    @Test("stream(conversation:) emits text deltas and persists both turns after .message")
    func streamConversation_persistsTurns() async throws {
        // Given
        let provider = MockStreamableProvider()
        provider.stubbedEvents = [
            .textDelta("Hello "),
            .textDelta("world"),
            .message(MockData.response)
        ]
        let client = AIClient(provider: provider)
        let conv = try await client.createConversation(model: "mock-model", title: "Stream")

        // When — collect all events
        let stream = try await client.stream(conversation: conv, message: "Hi")
        var collected: [AIStreamEvent] = []
        for try await event in stream {
            collected.append(event)
        }

        // Then — all events passed through
        #expect(collected.count == 3)

        // Then — turns were persisted after the .message event
        let stored = try #require(try await client.conversations().first { $0.id == conv.id })
        #expect(stored.turns.count == 2)
        #expect(stored.turns[0].message.role == .user)
        #expect(stored.turns[0].message.text == "Hi")
        #expect(stored.turns[1].message.role == .assistant)
    }

    @Test("stream(conversation:) throws conversationNotFound for an unknown conversation")
    func streamConversation_throwsForUnknown() async throws {
        // Given
        let client = AIClient(provider: MockStreamableProvider())
        let ghost = Conversation(title: "Ghost", model: "m")

        // When / Then — the throw happens eagerly before the stream is returned
        await #expect {
            _ = try await client.stream(conversation: ghost, message: "Hi")
        } throws: { error in
            guard let aiError = error as? AIError, case .conversationNotFound = aiError else { return false }
            return true
        }
    }

    @Test("stream(conversation:) throws providerUnsupported when provider is not StreamableProvider")
    func streamConversation_throwsWhenNotStreamable() async throws {
        // Given — MockAIProvider does NOT conform to StreamableProvider
        let client = AIClient(provider: MockAIProvider())
        let conv = try await client.createConversation(model: "mock-model", title: "No stream")

        // When / Then
        await #expect {
            _ = try await client.stream(conversation: conv, message: "Hi")
        } throws: { error in
            guard let aiError = error as? AIError, case .providerUnsupported = aiError else { return false }
            return true
        }
    }

    @Test("stream(conversation:tokenBudget:) trims oldest turns before building request")
    func streamWithBudget_trimsTurns() async throws {
        // Given
        let provider = MockStreamableProvider()
        provider.stubbedEvents = [.message(MockData.response)]
        let client = AIClient(provider: provider)
        let conv = try await client.createConversation(model: "mock-model", title: "Budget")

        // When — budget of 0 removes all prior turns from the request
        let stream = try await client.stream(conversation: conv, message: "Hi", tokenBudget: 0)
        for try await _ in stream {}

        // Then — request only contains the new user message
        let sentRequest = try #require(provider.receivedRequests.last)
        #expect(sentRequest.messages.count == 1)
    }

    @Test("stream(conversation:systemPrompt:) forwards the system prompt in the request")
    func streamConversation_forwardsSystemPrompt() async throws {
        // Given
        let provider = MockStreamableProvider()
        provider.stubbedEvents = [.message(MockData.response)]
        let client = AIClient(provider: provider)
        let conv = try await client.createConversation(model: "mock-model", title: "Sys")

        // When
        let stream = try await client.stream(conversation: conv, message: "Hi", systemPrompt: "Be brief.")
        for try await _ in stream {}

        // Then
        let sentRequest = try #require(provider.receivedRequests.last)
        #expect(sentRequest.systemPrompt == "Be brief.")
    }
}

// MARK: - MockModel helper

private enum MockModel: String, ProviderModel {
    case v1 = "mock-v1"
}
