import Foundation

/// The primary entry point for all AI interactions.
///
/// `AIClient` is an `actor` that holds a list of providers, routes requests to
/// the correct backend by model, and manages conversation persistence.
///
/// **Single provider (existing usage — unchanged):**
/// ```swift
/// let client = AIClient(
///     provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: "…")),
///     logger: AILogger(subsystem: "com.myapp", category: "ai")
/// )
/// let response = try await client.send(
///     AIRequestBuilder()
///         .model(ClaudeModel.sonnet46)
///         .addMessage(.user(text: "Hello!"))
///         .build()
/// )
/// ```
///
/// **Multiple providers — model-based routing:**
/// ```swift
/// let client = AIClient(providers: [claude, openai])
/// // Routed to ClaudeProvider because ClaudeModel.handles(_:) returns true
/// let response = try await client.send(
///     AIRequestBuilder().model(ClaudeModel.sonnet46).addMessage(…).build()
/// )
/// ```
///
/// **Per-conversation model:**
/// ```swift
/// let conv = try await client.createConversation(model: ClaudeModel.sonnet46, title: "Draft")
/// let reply = try await client.send(conversation: conv, message: "Hello")
/// ```
public actor AIClient {

    // MARK: - Public state

    /// All registered providers. Requests are routed to the first provider
    /// whose ``AIProvider/canHandle(model:)`` returns `true`.
    nonisolated public let providers: [any AIProvider]

    /// The primary (first) registered provider.
    ///
    /// Equivalent to `providers[0]`. Use this for single-provider setups or
    /// when you need a concrete reference for casting.
    nonisolated public var provider: any AIProvider { providers[0] }

    public let toolRegistry: ToolRegistry
    public let skillRegistry: SkillRegistry
    public let recipeRegistry: RecipeRegistry

    // MARK: - Private state

    private let logger: AILogger?
    private let store: any ConversationStore

    // MARK: - Init

    /// Creates a client with multiple providers.
    ///
    /// - Parameters:
    ///   - providers: Ordered list of providers. Routing picks the first that claims
    ///     the requested model via ``AIProvider/canHandle(model:)``.
    ///   - store: Persistence backend. Defaults to `.ephemeralMemory`.
    public init(
        providers: [any AIProvider],
        store: SupportedConversationStore = .ephemeralMemory,
        toolRegistry: ToolRegistry = ToolRegistry(),
        skillRegistry: SkillRegistry = SkillRegistry(),
        recipeRegistry: RecipeRegistry = RecipeRegistry(),
        logger: AILogger? = nil
    ) {
        precondition(!providers.isEmpty, "AIClient requires at least one provider.")
        self.providers = providers
        self.store = store.makeStore()
        self.toolRegistry = toolRegistry
        self.skillRegistry = skillRegistry
        self.recipeRegistry = recipeRegistry
        self.logger = logger
    }

    /// Convenience initialiser for single-provider setups.
    public init(
        provider: any AIProvider,
        store: SupportedConversationStore = .ephemeralMemory,
        toolRegistry: ToolRegistry = ToolRegistry(),
        skillRegistry: SkillRegistry = SkillRegistry(),
        recipeRegistry: RecipeRegistry = RecipeRegistry(),
        logger: AILogger? = nil
    ) {
        self.init(
            providers: [provider],
            store: store,
            toolRegistry: toolRegistry,
            skillRegistry: skillRegistry,
            recipeRegistry: recipeRegistry,
            logger: logger
        )
    }

    // MARK: - Send

    /// Sends a request and returns the complete response.
    ///
    /// Routes to the provider that claims the model via ``AIProvider/canHandle(model:)``.
    /// If the model returns tool calls they are executed automatically until the model stops.
    public func send(_ request: AIRequest) async throws -> AIResponse {
        let activeProvider = try resolveProvider(for: request.model)
        logger?.info(
            "[\(activeProvider.identifier)] Sending request model=\(request.model.identifier) messages=\(request.messages.count)"
        )

        var response = try await activeProvider.send(request)

        while response.requiresToolExecution {
            logger?.info("[\(activeProvider.identifier)] Executing \(response.toolUses.count) tool(s)")
            let toolResults = try await executeTools(response.toolUses, registry: toolRegistry)
            let followUp = appendingToolResults(toolResults, to: request, assistantResponse: response)
            response = try await activeProvider.send(followUp)
        }

        let stopReason = response.stopReason.rawValue
        let tokens = response.usage.totalTokens
        logger?.info("[\(activeProvider.identifier)] Response received stopReason=\(stopReason) tokens=\(tokens)")
        return response
    }

    // MARK: - Stream

    /// Returns a live stream of events from the provider that handles the request's model.
    ///
    /// - Note: Automatic tool execution is not performed during streaming.
    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        let provider: any AIProvider
        do {
            provider = try resolveProvider(for: request.model)
        } catch {
            // Propagate the real error (e.g. noProviderForModel) rather than swallowing it
            // with try? and misreporting providerUnsupported(.streaming).
            let (stream, continuation) = AsyncThrowingStream<AIStreamEvent, any Error>.makeStream()
            continuation.finish(throwing: error)
            return stream
        }
        guard let streamable = provider as? any StreamableProvider else {
            let (stream, continuation) = AsyncThrowingStream<AIStreamEvent, any Error>.makeStream()
            continuation.finish(throwing: AIError.providerUnsupported(capability: .streaming))
            return stream
        }
        logger?.info("[\(streamable.identifier)] Starting stream model=\(request.model.identifier)")
        return streamable.stream(request)
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

    // MARK: - Recipes

    /// Renders a `Recipe` with the given values and sends it as a request.
    public func send(
        recipe: Recipe,
        values: [String: String] = [:],
        model: AIModel,
        additionalTools: [Tool] = []
    ) async throws(AIError) -> AIResponse {
        let rendered = try recipe.render(with: values)
        let request = try AIRequestBuilder()
            .model(model)
            .systemPrompt(rendered.systemPrompt ?? "")
            .addMessage(.user(text: rendered.userPrompt))
            .tools(await toolRegistry.allTools + additionalTools)
            .build()
        do {
            return try await send(request)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.requestBuildingFailed(error.localizedDescription)
        }
    }

    // MARK: - Skills

    /// Executes a registered skill by identifier.
    public func execute(skillId: String, input: String, model: AIModel) async throws -> SkillResult {
        let skill = try await skillRegistry.skill(id: skillId)
        logger?.info("Executing skill '\(skillId)'")

        var builder = AIRequestBuilder()
            .model(model)
            .tools(skill.tools + (await toolRegistry.allTools))
            .addMessage(.user(text: input))

        if let recipe = skill.recipe {
            let rendered = try recipe.render(with: [:])
            if let system = rendered.systemPrompt { builder = builder.systemPrompt(system) }
        }

        let request = try builder.build()
        let response = try await send(request)
        return try await skill.process(response: response)
    }

    // MARK: - Conversation API

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
        guard var current = try await store.conversation(byId: conversation.id) else {
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

    // MARK: - Private helpers

    /// Returns the first provider that claims the given model.
    private func resolveProvider(for model: AIModel) throws(AIError) -> any AIProvider {
        guard let resolved = providers.first(where: { $0.canHandle(model: model) }) else {
            throw AIError.noProviderForModel(model)
        }
        return resolved
    }

    private func executeTools(
        _ uses: [ContentBlock.ToolUseContent],
        registry: ToolRegistry
    ) async throws(AIError) -> [(use: ContentBlock.ToolUseContent, result: JSONValue)] {
        do {
            return try await withThrowingTaskGroup(of: (ContentBlock.ToolUseContent, JSONValue).self) { group in
                for use in uses {
                    group.addTask {
                        do {
                            let result = try await registry.execute(toolName: use.name, input: use.input)
                            return (use, result)
                        } catch let error as AIError {
                            throw error
                        } catch is CancellationError {
                            throw AIError.cancelled
                        } catch {
                            throw AIError.toolExecutionFailed(toolName: use.name, underlying: error)
                        }
                    }
                }
                return try await group.reduce(into: []) { $0.append($1) }
            }
        } catch let error as AIError {
            throw error
        } catch is CancellationError {
            throw AIError.cancelled
        } catch {
            throw AIError.toolExecutionFailed(toolName: "unknown", underlying: error)
        }
    }

    private func appendingToolResults(
        _ results: [(use: ContentBlock.ToolUseContent, result: JSONValue)],
        to request: AIRequest,
        assistantResponse: AIResponse
    ) -> AIRequest {
        let assistantMessage = Message(role: .assistant, content: assistantResponse.content)
        let toolResultBlocks: [ContentBlock] = results.map { pair in
            .toolResult(.init(
                toolUseId: pair.use.id,
                content: [.text(pair.result.description)],
                isError: false
            ))
        }
        let userMessage = Message(role: .user, content: toolResultBlocks)
        return AIRequest(
            messages: request.messages + [assistantMessage, userMessage],
            model: request.model,
            systemPrompt: request.systemPrompt,
            tools: request.tools,
            maxTokens: request.maxTokens,
            temperature: request.temperature,
            topP: request.topP,
            stopSequences: request.stopSequences
        )
    }
}
