import AIProviderKit

/// The set of models supported by ``AppleIntelligenceProvider``.
///
/// Use these cases wherever an ``AIModel`` or ``ProviderModel`` is expected:
///
/// ```swift
/// AIRequestBuilder().model(AppleIntelligenceModel.default)
/// ```
public enum AppleIntelligenceModel: String, ProviderModel {
    /// The default on-device Apple Intelligence model via `FoundationModels`.
    case `default` = "com.apple.foundation-models.default"
}
