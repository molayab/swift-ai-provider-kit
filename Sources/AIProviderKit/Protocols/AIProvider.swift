/// The core abstraction for any AI provider (Claude, OpenAI, on-device, …).
///
/// Conform to this protocol to add a new provider without touching `AIClient`
/// or any other core type (Open/Closed Principle).
public protocol AIProvider: Sendable {

    /// A stable, lowercase identifier (e.g. `"claude"`, `"openai"`).
    var identifier: String { get }

    /// The set of capabilities this provider supports.
    var capabilities: Set<AICapability> { get }

    /// Returns `true` when this provider can handle the given model.
    ///
    /// `AIClient` calls this to route each request to the correct backend in a
    /// multi-provider setup. The default implementation returns `true`, which is
    /// appropriate when only one provider is registered. Override this in each
    /// concrete provider to return `true` only for models the provider owns.
    func canHandle(model: AIModel) -> Bool

    /// Sends a request and awaits a complete response.
    func send(_ request: AIRequest) async throws(AIError) -> AIResponse
}

public extension AIProvider {
    func canHandle(model: AIModel) -> Bool { true }
}

/// Extends `AIProvider` with server-sent event streaming.
///
/// Implement this alongside `AIProvider` when the backend supports streaming.
public protocol StreamableProvider: AIProvider {
    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, any Error>
}

/// Extends `AIProvider` with the ability to enumerate available models at runtime.
///
/// Implement this alongside `AIProvider` when the backend exposes a model-listing endpoint.
/// Static `AIModel` constants remain the primary recommendation for known stable models;
/// `ModelDiscoveryProvider` complements them for dynamic UIs, fine-tuned models, or
/// testing with the latest preview releases without an SDK update.
///
/// ```swift
/// if let discovery = provider as? any ModelDiscoveryProvider {
///     let models = try await discovery.listModels()
/// }
/// ```
public protocol ModelDiscoveryProvider: AIProvider {
    /// Fetches the list of models available to the current API key.
    ///
    /// - Returns: An array of ``AIModelInfo`` sorted by provider-defined order (typically newest first).
    /// - Throws: ``AIError`` on network, auth, or decoding failure.
    func listModels() async throws(AIError) -> [AIModelInfo]
}

// MARK: - Default capability guard

public extension AIProvider {
    func assertSupports(_ capability: AICapability) throws(AIError) {
        guard capabilities.contains(capability) else {
            throw AIError.providerUnsupported(capability: capability)
        }
    }
}
