/// A provider-agnostic request to an AI model.
///
/// Build via `AIRequestBuilder` for a fluent, validated API.
public struct AIRequest: Sendable {

    /// The ordered conversation history, including the new user turn.
    public let messages: [Message]
    /// The model to use for this request.
    public let model: AIModel
    /// Optional top-level instruction prepended before the conversation.
    public let systemPrompt: String?
    /// Tools the model may call during this turn.
    public let tools: [Tool]
    /// Maximum number of tokens the model may generate. Default: `4096`.
    public let maxTokens: Int
    /// Sampling temperature (0–1). `nil` uses the provider's default.
    public let temperature: Double?
    /// Nucleus sampling parameter (0–1). `nil` uses the provider's default.
    public let topP: Double?
    /// Sequences that cause the model to stop generating immediately.
    public let stopSequences: [String]

    public init(
        messages: [Message],
        model: AIModel,
        systemPrompt: String? = nil,
        tools: [Tool] = [],
        maxTokens: Int = 4_096,
        temperature: Double? = nil,
        topP: Double? = nil,
        stopSequences: [String] = []
    ) {
        self.messages = messages
        self.model = model
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.stopSequences = stopSequences
    }
}
