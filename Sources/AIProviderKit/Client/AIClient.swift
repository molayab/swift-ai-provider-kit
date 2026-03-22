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
    let store: any ConversationStore

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

    // MARK: - Private helpers

    /// Returns the first provider that claims the given model.
    func resolveProvider(for model: AIModel) throws(AIError) -> any AIProvider {
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
