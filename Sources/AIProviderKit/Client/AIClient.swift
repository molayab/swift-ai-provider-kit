/// The primary entry point for all AI interactions.
///
/// `AIClient` is an `actor` that coordinates a provider, authorization,
/// registries, and automatic tool-execution loops.
///
/// ```swift
/// let client = AIClient(
///     provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: "<ANTHROPIC_API_KEY>")),
///     logger: AILogger(subsystem: "com.myapp", category: "ai")
/// )
/// let response = try await client.send(
///     AIRequestBuilder()
///         .model(.claudeSonnet46)
///         .addMessage(.user(text: "Hello!"))
///         .build()
/// )
/// ```
public actor AIClient {
    public nonisolated let provider: any AIProvider
    private let logger: AILogger?

    public let toolRegistry: ToolRegistry
    public let skillRegistry: SkillRegistry
    public let recipeRegistry: RecipeRegistry

    public init(
        provider: any AIProvider,
        toolRegistry: ToolRegistry = ToolRegistry(),
        skillRegistry: SkillRegistry = SkillRegistry(),
        recipeRegistry: RecipeRegistry = RecipeRegistry(),
        logger: AILogger? = nil
    ) {
        self.provider = provider
        self.toolRegistry = toolRegistry
        self.skillRegistry = skillRegistry
        self.recipeRegistry = recipeRegistry
        self.logger = logger
    }

    // MARK: - Send

    /// Sends a request and returns the complete response.
    ///
    /// If the model requests tool calls, they are executed automatically and
    /// a follow-up request is sent until the model stops requesting tools.
    public func send(_ request: AIRequest) async throws -> AIResponse {
        logger?.info(
            "[\(provider.identifier)] Sending request model=\(request.model.identifier) messages=\(request.messages.count)"
        )

        var response = try await provider.send(request)

        while response.requiresToolExecution {
            logger?.info("[\(provider.identifier)] Executing \(response.toolUses.count) tool(s)")
            let toolResults = try await executeTools(response.toolUses, registry: toolRegistry)
            let followUp = appendingToolResults(toolResults, to: request, assistantResponse: response)
            response = try await provider.send(followUp)
        }

        let stopReason = response.stopReason.rawValue
        let tokens = response.usage.totalTokens
        logger?.info("[\(provider.identifier)] Response received stopReason=\(stopReason) tokens=\(tokens)")
        return response
    }

    // MARK: - Stream

    /// Returns a live stream of events from the provider.
    ///
    /// - Note: Automatic tool execution is not performed during streaming.
    ///   Collect the full `AIResponse` from the `.message` event and call
    ///   `send(_:)` for tool-use turns.
    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        guard let streamable = provider as? any StreamableProvider else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: AIError.providerUnsupported(capability: .streaming))
            }
        }
        logger?.info("[\(provider.identifier)] Starting stream model=\(request.model.identifier)")
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
                            // Preserves the tool name for any unexpected non-AIError.
                            throw AIError.toolExecutionFailed(toolName: use.name, underlying: error)
                        }
                    }
                }
                return try await group.reduce(into: []) { $0.append($1) }
            }
        } catch let error as AIError {
            throw error
        } catch is CancellationError {
            // Parent task was cancelled while waiting for the group.
            throw AIError.cancelled
        } catch {
            // Unreachable in practice; every task wraps errors as AIError above.
            // Required only for the compiler's typed-throw conversion at this boundary.
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
