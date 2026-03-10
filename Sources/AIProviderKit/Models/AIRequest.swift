/// A provider-agnostic request to an AI model.
///
/// Build via `AIRequestBuilder` for a fluent, validated API.
public struct AIRequest: Sendable {

    public let messages: [Message]
    public let model: AIModel
    public let systemPrompt: String?
    public let tools: [Tool]
    public let maxTokens: Int
    public let temperature: Double?
    public let topP: Double?
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
