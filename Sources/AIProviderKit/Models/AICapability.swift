/// A capability that an AI provider may or may not support.
///
/// Use this to guard against calling unsupported features on a provider
/// before making a request.
public enum AICapability: String, Sendable, Hashable, CaseIterable {
    case text
    case vision
    case tools
    case streaming
    case systemPrompt
    /// The provider can enumerate its available models via ``ModelDiscoveryProvider``.
    case modelDiscovery
}
