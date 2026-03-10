/// A provider-agnostic response from an AI model.
public struct AIResponse: Sendable {

    /// The provider-specific message identifier.
    public let id: String

    /// The model identifier that produced this response.
    public let model: String

    /// The content blocks returned by the model.
    public let content: [ContentBlock]

    /// Token consumption for this turn.
    public let usage: TokenUsage

    /// Why the model stopped generating.
    public let stopReason: StopReason

    public init(
        id: String,
        model: String,
        content: [ContentBlock],
        usage: TokenUsage,
        stopReason: StopReason
    ) {
        self.id = id
        self.model = model
        self.content = content
        self.usage = usage
        self.stopReason = stopReason
    }
}

// MARK: - Convenience

public extension AIResponse {
    /// Returns the concatenated text from all `.text` content blocks.
    var text: String {
        content.compactMap(\.textValue).joined()
    }

    /// All tool-use blocks, if the model requested tool calls.
    var toolUses: [ContentBlock.ToolUseContent] {
        content.compactMap {
            if case .toolUse(let use) = $0 { return use }
            return nil
        }
    }

    /// Whether the model is waiting for tool results before continuing.
    var requiresToolExecution: Bool {
        stopReason == .toolUse
    }
}
