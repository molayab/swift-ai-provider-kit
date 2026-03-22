/// A typed, provider-owned model identifier.
///
/// Each provider target defines its own `ProviderModel`-conforming enum, making the set
/// of supported models explicit and compile-time checked. The enum's raw values are the
/// string identifiers forwarded to the API.
///
/// ```swift
/// // ClaudeProvider defines:
/// public enum ClaudeModel: String, ProviderModel { case sonnet46 = "claude-sonnet-4-6" }
///
/// // Call sites use the typed enum directly:
/// AIRequestBuilder().model(ClaudeModel.sonnet46)
/// ```
///
/// `AIClient` uses `canHandle(model:)` — driven by each provider's enum — to route requests
/// to the correct backend in a multi-provider setup.
public protocol ProviderModel: RawRepresentable, CaseIterable, Sendable, Hashable
    where RawValue == String {
}

public extension ProviderModel {
    /// The `AIModel` value derived from this case's raw string identifier.
    var aiModel: AIModel { AIModel(rawValue) }

    /// Returns `true` when the given `AIModel` matches one of this type's cases.
    static func handles(_ model: AIModel) -> Bool {
        allCases.contains { $0.rawValue == model.identifier }
    }
}
