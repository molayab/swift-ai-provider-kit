/// A feature that an AI provider may or may not support.
///
/// Capabilities let you guard against calling unsupported features before making a request,
/// and allow the framework to surface meaningful errors when a provider cannot fulfil an
/// operation.
///
/// ## Checking support
///
/// Inspect ``AIProvider/capabilities`` to branch on what the active provider can do:
///
/// ```swift
/// if client.provider.capabilities.contains(.streaming) {
///     for try await event in client.stream(request) { … }
/// } else {
///     let response = try await client.send(request)
/// }
/// ```
///
/// You can also use the throwing helper ``AIProvider/assertSupports(_:)``, which throws
/// ``AIError/providerUnsupported(capability:)`` when the capability is absent:
///
/// ```swift
/// try client.provider.assertSupports(.vision)
/// ```
///
/// ## Topics
///
/// ### Text and vision
/// - ``text``
/// - ``vision``
///
/// ### Interactive features
/// - ``tools``
/// - ``streaming``
/// - ``systemPrompt``
///
/// ### Model management
/// - ``modelDiscovery``
public enum AICapability: String, Sendable, Hashable, CaseIterable {

    /// The provider accepts plain-text messages and returns text responses.
    ///
    /// This is the baseline capability required for every provider.
    case text

    /// The provider accepts image inputs alongside text.
    ///
    /// When present, ``ContentBlock`` image blocks are forwarded to the model.
    /// Providers that lack this capability will ignore or reject image content.
    case vision

    /// The provider supports tool use (function calling).
    ///
    /// When present, ``AIClient`` can register tools via ``AIClient/toolRegistry`` and
    /// the model may request their execution during a turn.
    case tools

    /// The provider supports server-sent event streaming via ``StreamableProvider``.
    ///
    /// When present, ``AIClient/stream(_:)`` returns a live ``AsyncThrowingStream``
    /// of ``AIStreamEvent`` values. Providers that lack this capability will cause
    /// ``AIClient/stream(_:)`` to throw ``AIError/providerUnsupported(capability:)``.
    case streaming

    /// The provider honours a top-level system prompt.
    ///
    /// When present, the ``AIRequest/systemPrompt`` field is forwarded to the model.
    /// Providers that lack this capability silently drop the system prompt or fold it
    /// into the first user message.
    case systemPrompt

    /// The provider can enumerate its available models at runtime via ``ModelDiscoveryProvider``.
    ///
    /// When present, cast the provider with ``AIProvider/castAs(_:)`` and call
    /// ``ModelDiscoveryProvider/listModels()`` to retrieve the current model list:
    ///
    /// ```swift
    /// let models = try await client.provider.castAs(OpenAIProvider.self).listModels()
    /// ```
    case modelDiscovery
}
