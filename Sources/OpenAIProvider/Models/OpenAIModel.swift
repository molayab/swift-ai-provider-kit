import AIProviderKit

/// The set of models supported by ``OpenAIProvider``.
///
/// Use these cases wherever an ``AIModel`` or ``ProviderModel`` is expected:
///
/// ```swift
/// AIRequestBuilder().model(OpenAIModel.gpt41)
/// ```
///
/// The raw string values are the identifiers forwarded to the OpenAI API.
public enum OpenAIModel: String, ProviderModel {
    /// GPT-4.1 — flagship instruction-following model, 1M-token context.
    case gpt41     = "gpt-4.1"
    /// GPT-4.1 Mini — smaller, faster variant of GPT-4.1.
    case gpt41Mini = "gpt-4.1-mini"
    /// GPT-4.1 Nano — fastest and most cost-efficient GPT-4.1 variant.
    case gpt41Nano = "gpt-4.1-nano"
    /// GPT-4o — OpenAI's multimodal model (superseded by GPT-4.1).
    case gpt4o     = "gpt-4o"
    /// GPT-4o Mini — smaller, faster variant of GPT-4o.
    case gpt4oMini = "gpt-4o-mini"
    /// o3 — advanced reasoning model.
    case o3        = "o3"
    /// o3-mini — compact reasoning model.
    case o3Mini    = "o3-mini"
    /// o4-mini — fast, cost-efficient reasoning model optimised for coding and vision tasks.
    case o4Mini    = "o4-mini"
}
