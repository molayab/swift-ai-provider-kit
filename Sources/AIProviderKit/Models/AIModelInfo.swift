import Foundation

/// Metadata about a model returned from a provider's model-listing API.
///
/// Providers that conform to `ModelDiscoveryProvider` return arrays of this type.
/// The `model` property is ready to use directly in `AIRequestBuilder.model(_:)`.
public struct AIModelInfo: Sendable, Equatable {

    /// The model identifier, usable directly in `AIRequestBuilder.model(_:)`.
    public let model: AIModel

    /// Human-readable name, if the provider returns one (e.g. `"GPT-4o"`, `"Claude Opus 4.6"`).
    public let displayName: String?

    /// When the model was created / released, if the provider returns a timestamp.
    public let createdAt: Date?

    public init(model: AIModel, displayName: String? = nil, createdAt: Date? = nil) {
        self.model = model
        self.displayName = displayName
        self.createdAt = createdAt
    }
}
