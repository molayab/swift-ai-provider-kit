import Foundation

// MARK: - Conversation API

extension AIClient {

    /// Creates and persists a new conversation bound to the given model.
    public func createConversation(
        model: AIModel,
        title: String
    ) async throws -> Conversation {
        try await store.createConversation(title: title, model: model)
    }

    /// Creates and persists a new conversation using a typed ``ProviderModel`` case.
    public func createConversation<M: ProviderModel>(
        model: M,
        title: String
    ) async throws -> Conversation {
        try await createConversation(model: model.aiModel, title: title)
    }

    /// Sends a user message within an existing conversation, persisting both the
    /// user turn and the assistant reply.
    ///
    /// The provider is resolved from the conversation's stored model, so the caller
    /// never needs to specify a provider or model after creating the conversation.
    /// Always loads the latest stored state before sending, so any `Conversation`
    /// value — even a stale one from a previous session — can be passed safely.
    ///
    /// - Parameters:
    ///   - conversation: The target conversation (stale values are safe).
    ///   - message: The user's message text.
    ///   - tokenBudget: When set, prunes the oldest turns before building the request
    ///     so the total token count stays within this limit.
    public func send(
        conversation: Conversation,
        message: String,
        systemPrompt: String? = nil,
        tokenBudget: Int? = nil
    ) async throws -> AIResponse {
        let ctx = try await prepareConversationRequest(
            for: conversation,
            message: message,
            systemPrompt: systemPrompt,
            tokenBudget: tokenBudget
        )
        let response = try await send(ctx.request)
        // Reload latest state before writing to avoid reentrancy data loss: another
        // concurrent send may have appended turns while we were suspended in send(request).
        try await persistTurns(conversationId: ctx.current.id, userMessage: ctx.userMessage, response: response)
        return response
    }

    /// Streams a user message within an existing conversation, persisting both turns
    /// when the stream completes.
    ///
    /// This combines the streaming UX of ``stream(_:)`` with the automatic persistence
    /// of ``send(conversation:message:systemPrompt:tokenBudget:)``. The `.message` event
    /// at the end of the stream carries the full assembled response and triggers the store write.
    ///
    /// ```swift
    /// let events = try await client.stream(conversation: conv, message: "Hello")
    /// for try await event in events {
    ///     if case .textDelta(let text) = event { print(text, terminator: "") }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - conversation: The target conversation (stale values are safe).
    ///   - message: The user's message text.
    ///   - tokenBudget: When set, prunes the oldest turns before building the request.
    public func stream(
        conversation: Conversation,
        message: String,
        systemPrompt: String? = nil,
        tokenBudget: Int? = nil
    ) async throws -> AsyncThrowingStream<AIStreamEvent, any Error> {
        // All actor-isolated setup happens here before the stream is handed to the caller.
        let ctx = try await prepareConversationRequest(
            for: conversation,
            message: message,
            systemPrompt: systemPrompt,
            tokenBudget: tokenBudget
        )
        guard let streamable = (try resolveProvider(for: ctx.request.model)) as? any StreamableProvider else {
            throw AIError.providerUnsupported(capability: .streaming)
        }

        let capturedConversationId = ctx.current.id
        let capturedUserMessage = ctx.userMessage

        let (stream, continuation) = AsyncThrowingStream<AIStreamEvent, any Error>.makeStream()
        let task = Task {
            do {
                for try await event in streamable.stream(ctx.request) {
                    continuation.yield(event)
                    // Persist both turns once the provider emits the final assembled response.
                    // Reload from the store immediately before saving to avoid reentrancy data
                    // loss: another concurrent send may have appended turns while we were
                    // suspended waiting for the stream to complete.
                    if case .message(let response) = event {
                        try await self.persistTurns(
                            conversationId: capturedConversationId,
                            userMessage: capturedUserMessage,
                            response: response
                        )
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    /// Returns the stored conversation with the given identifier, or `nil` if not found.
    public func conversation(byId id: UUID) async throws -> Conversation? {
        try await store.conversation(byId: id)
    }

    /// Returns all stored conversations, newest first.
    public func conversations() async throws -> [Conversation] {
        try await store.allConversations()
    }

    /// Deletes a conversation and all its turns.
    public func delete(conversation: Conversation) async throws {
        try await store.delete(conversation)
    }

    /// Archives a conversation.
    public func archive(conversation: Conversation) async throws {
        try await store.archive(conversation)
    }
}

// MARK: - Private helpers

private struct ConversationRequestContext {
    let current: Conversation
    let userMessage: Message
    let request: AIRequest
}

extension AIClient {

    /// Loads the latest conversation state, applies optional budget trimming, and builds
    /// the `AIRequest` for a conversation turn. Used by both `send(conversation:)` and
    /// `stream(conversation:)` to eliminate duplicated setup logic.
    private func prepareConversationRequest(
        for conversation: Conversation,
        message: String,
        systemPrompt: String?,
        tokenBudget: Int?
    ) async throws -> ConversationRequestContext {
        guard let current = try await store.conversation(byId: conversation.id) else {
            throw AIError.conversationNotFound(conversation.id.uuidString)
        }
        var turns = current.turns
        if let budget = tokenBudget {
            turns = TokenBudgetTrimmer.trim(turns, toBudget: budget)
        }
        var messages = turns.map(\.message)
        let userMessage = Message.user(text: message)
        messages.append(userMessage)

        let allTools = await toolRegistry.allTools
        var builder = AIRequestBuilder()
            .model(current.model)
            .messages(messages)
            .tools(allTools)
        if let prompt = systemPrompt { builder = builder.systemPrompt(prompt) }
        let request = try builder.build()
        return ConversationRequestContext(current: current, userMessage: userMessage, request: request)
    }

    /// Reloads the latest conversation state and appends the user and assistant turns,
    /// then saves. Used by both `send(conversation:)` and `stream(conversation:)` after
    /// the provider responds, guarding against reentrancy data loss.
    private func persistTurns(
        conversationId: UUID,
        userMessage: Message,
        response: AIResponse
    ) async throws {
        guard var latest = try await store.conversation(byId: conversationId) else {
            throw AIError.conversationNotFound(conversationId.uuidString)
        }
        latest.turns.append(ConversationTurn(message: userMessage))
        latest.turns.append(ConversationTurn(
            message: Message(role: .assistant, content: response.content),
            tokenUsage: response.usage
        ))
        try await store.save(latest)
    }
}
