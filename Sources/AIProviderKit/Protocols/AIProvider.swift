/// The core abstraction for any AI provider (Claude, OpenAI, on-device, …).
///
/// Conform to this protocol to add a new provider without touching `AIClient`
/// or any other core type (Open/Closed Principle).
public protocol AIProvider: Sendable {

    /// A stable, lowercase identifier (e.g. `"claude"`, `"openai"`).
    var identifier: String { get }

    /// The set of capabilities this provider supports.
    var capabilities: Set<AICapability> { get }

    /// Sends a request and awaits a complete response.
    func send(_ request: AIRequest) async throws(AIError) -> AIResponse
}

/// Extends `AIProvider` with server-sent event streaming.
///
/// Implement this alongside `AIProvider` when the backend supports streaming.
public protocol StreamableProvider: AIProvider {
    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, any Error>
}

// MARK: - Default capability guard

public extension AIProvider {
    func assertSupports(_ capability: AICapability) throws(AIError) {
        guard capabilities.contains(capability) else {
            throw AIError.providerUnsupported(capability: capability)
        }
    }
}
