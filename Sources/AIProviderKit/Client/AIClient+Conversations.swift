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
        // Always reload the latest state — safe to pass stale Conversation values
        guard let current = try await store.conversation(byId: conversation.id) else {
            throw AIError.conversationNotFound(conversation.id.uuidString)
        }

        // Trim history if a token budget is set
        var turns = current.turns
        if let budget = tokenBudget {
            turns = TokenBudgetTrimmer.trim(turns, toBudget: budget)
        }

        // Build the message history from stored turns
        var messages = turns.map(\.message)
        let userMessage = Message.user(text: message)
        messages.append(userMessage)

        var builder = AIRequestBuilder()
            .model(current.model)
            .messages(messages)
            .tools(await toolRegistry.allTools)
        if let prompt = systemPrompt { builder = builder.systemPrompt(prompt) }
        let request = try builder.build()

        let response = try await send(request)

        // Reload latest state before writing to avoid reentrancy data loss: another
        // concurrent send may have appended turns while we were suspended in send(request).
        guard var latest = try await store.conversation(byId: conversation.id) else {
            throw AIError.conversationNotFound(conversation.id.uuidString)
        }
        latest.turns.append(ConversationTurn(message: userMessage))
        latest.turns.append(ConversationTurn(
            message: Message(role: .assistant, content: response.content),
            tokenUsage: response.usage
        ))
        try await store.save(latest)

        return response
    }

    /// Streams a user message within an existing conversation, persisting both turns
    /// when the stream completes.
    ///
    /// This combines the streaming UX of ``stream(_:)`` with the automatic persistence
    /// of ``send(conversation:message:tokenBudget:)``. The `.message` event at the end
    /// of the stream carries the full assembled response and triggers the store write.
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

        guard let streamable = (try resolveProvider(for: request.model)) as? any StreamableProvider else {
            throw AIError.providerUnsupported(capability: .streaming)
        }

        // Capture Sendable values for use inside the unstructured Task.
        let capturedStore = store
        let capturedUserMessage = userMessage
        let capturedConversationId = current.id

        let (stream, continuation) = AsyncThrowingStream<AIStreamEvent, any Error>.makeStream()
        let task = Task {
            do {
                for try await event in streamable.stream(request) {
                    continuation.yield(event)
                    // Persist both turns once the provider emits the final assembled response.
                    // Reload from the store immediately before saving to avoid reentrancy data
                    // loss: another concurrent send may have appended turns while we were
                    // suspended waiting for the stream to complete.
                    if case .message(let response) = event {
                        guard var latest = try await capturedStore.conversation(byId: capturedConversationId) else { break }
                        latest.turns.append(ConversationTurn(message: capturedUserMessage))
                        latest.turns.append(ConversationTurn(
                            message: Message(role: .assistant, content: response.content),
                            tokenUsage: response.usage
                        ))
                        try await capturedStore.save(latest)
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
