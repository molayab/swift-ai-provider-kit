/// An opaque model identifier passed through to the underlying provider.
///
/// Each provider target (e.g. `ClaudeProvider`) exposes its own `AIModel`
/// constants as a `static` extension.
///
/// ```swift
/// let request = AIRequestBuilder()
///     .model(ClaudeModel.sonnet46)
///     .build()
/// ```
public struct AIModel: Hashable, Sendable, Codable, ExpressibleByStringLiteral {

    public let identifier: String

    public init(_ identifier: String) {
        self.identifier = identifier
    }

    public init(stringLiteral value: String) {
        self.identifier = value
    }
}
