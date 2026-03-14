/// A fluent builder for `AIRequest`.
///
/// All setters return `Self` for chaining. Call `build()` to produce a
/// validated `AIRequest`, or `build(throwingIfInvalid:)` for inline use.
///
/// ```swift
/// let request = try AIRequestBuilder()
///     .model(.claudeSonnet4)
///     .systemPrompt("You are a helpful assistant.")
///     .conversation {
///         Message.user(text: "What is 2 + 2?")
///     }
///     .maxTokens(256)
///     .build()
/// ```
public final class AIRequestBuilder {

    private var messages: [Message] = []
    private var model: AIModel?
    private var systemPrompt: String?
    private var tools: [Tool] = []
    private var maxTokens: Int = 4_096
    private var temperature: Double?
    private var topP: Double?
    private var stopSequences: [String] = []

    public init() {}

    // MARK: - Setters

    @discardableResult public func model(_ model: AIModel) -> Self {
        self.model = model
        return self
    }

    @discardableResult public func systemPrompt(_ prompt: String) -> Self {
        self.systemPrompt = prompt
        return self
    }

    @discardableResult public func messages(_ messages: [Message]) -> Self {
        self.messages = messages
        return self
    }

    @discardableResult public func addMessage(_ message: Message) -> Self {
        self.messages.append(message)
        return self
    }

    /// Append multiple messages using a result-builder closure.
    @discardableResult public func conversation(@ConversationBuilder _ build: () -> [Message]) -> Self {
        self.messages.append(contentsOf: build())
        return self
    }

    @discardableResult public func tools(_ tools: [Tool]) -> Self {
        self.tools = tools
        return self
    }

    @discardableResult public func addTool(_ tool: Tool) -> Self {
        self.tools.append(tool)
        return self
    }

    @discardableResult public func maxTokens(_ maxTokens: Int) -> Self {
        self.maxTokens = maxTokens
        return self
    }

    @discardableResult public func temperature(_ temperature: Double) -> Self {
        self.temperature = temperature
        return self
    }

    @discardableResult public func topP(_ topP: Double) -> Self {
        self.topP = topP
        return self
    }

    @discardableResult public func stopSequences(_ sequences: [String]) -> Self {
        self.stopSequences = sequences
        return self
    }

    // MARK: - Build

    /// Validates and returns the constructed `AIRequest`.
    ///
    /// - Throws: `AIError.requestBuildingFailed` if required fields are missing.
    public func build() throws -> AIRequest {
        guard let model else {
            throw AIError.requestBuildingFailed("A model must be specified.")
        }
        guard !messages.isEmpty else {
            throw AIError.requestBuildingFailed("At least one message is required.")
        }
        return AIRequest(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            tools: tools,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            stopSequences: stopSequences
        )
    }
}
