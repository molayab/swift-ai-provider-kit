import AIProviderKit

/// The set of models supported by ``ClaudeProvider``.
///
/// Use these cases wherever an ``AIModel`` or ``ProviderModel`` is expected:
///
/// ```swift
/// AIRequestBuilder().model(ClaudeModel.sonnet46)
/// ```
///
/// The raw string values are the identifiers forwarded to the Anthropic API.
public enum ClaudeModel: String, ProviderModel {
    /// Claude Haiku 4.5 — fastest model with near-frontier intelligence, 200k-token context.
    case haiku45  = "claude-haiku-4-5-20251001"
    /// Claude Sonnet 4.6 — best balance of speed and intelligence, 1M-token context.
    case sonnet46 = "claude-sonnet-4-6"
    /// Claude Opus 4.6 — Anthropic's most intelligent model, built for complex agentic tasks.
    case opus46   = "claude-opus-4-6"
}
