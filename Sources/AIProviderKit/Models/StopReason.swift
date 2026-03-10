/// The reason the model stopped generating tokens.
public enum StopReason: String, Sendable, Equatable, Codable {
    /// The model reached a natural end of its response.
    case endTurn
    /// The response was cut off by `maxTokens`.
    case maxTokens
    /// A custom stop sequence was matched.
    case stopSequence
    /// The model is requesting a tool call.
    case toolUse
    /// Unknown stop reason returned by the provider.
    case unknown
}
