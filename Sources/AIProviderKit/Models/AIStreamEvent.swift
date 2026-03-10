/// An event emitted during a streaming response.
public enum AIStreamEvent: Sendable {

    /// An incremental text chunk from the model.
    case textDelta(String)

    /// An incremental chunk of a tool-call input JSON.
    case toolUseDelta(id: String, name: String, inputDelta: String)

    /// The final, complete response (delivered at stream end).
    case message(AIResponse)
}
