import Foundation

/// Errors thrown by AIProviderKit operations.
public enum AIError: Error, Sendable {
    /// The provider rejected the request due to missing or invalid credentials.
    case authorizationFailed(String)
    /// A transport-level failure occurred while communicating with the provider.
    case networkError(URLError)
    /// The provider returned an unexpected HTTP status code.
    case invalidResponse(statusCode: Int, body: String?)
    /// The provider response could not be parsed (JSON or wire-format error).
    case decodingFailed(underlying: any Error)
    /// The request body could not be serialised before sending.
    case encodingFailed(underlying: any Error)
    /// The provider does not support the requested capability.
    case providerUnsupported(capability: AICapability)
    /// The provider is of a different concrete type than expected by `castAs(_:)`.
    case providerTypeMismatch(expected: String, actual: String)
    /// A registered tool's handler threw an error during execution.
    case toolExecutionFailed(toolName: String, underlying: any Error)
    /// No tool with the given name is registered in the `ToolRegistry`.
    case toolNotFound(String)
    /// A recipe could not be rendered because required placeholder keys are missing.
    case recipeRenderingFailed(recipeId: String, missingKeys: [String])
    /// No recipe with the given identifier is registered in the `RecipeRegistry`.
    case recipeNotFound(String)
    /// No skill with the given identifier is registered in the `SkillRegistry`.
    case skillNotFound(String)
    /// The `AIRequestBuilder` produced an invalid request.
    case requestBuildingFailed(String)
    /// The provider is temporarily rate-limited; retry after the given interval if provided.
    case rateLimitExceeded(retryAfter: TimeInterval?)
    /// The request exceeds the model's maximum context window.
    case contextLengthExceeded
    /// The specified model identifier is not recognised by the provider.
    case invalidModel(String)
    /// The model runtime failed during inference (session error, guardrail rejection, etc.).
    case inferenceFailed(underlying: any Error)
    /// The operation was cancelled before it could complete.
    case cancelled
}

// MARK: - LocalizedError

extension AIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authorizationFailed(let msg):
            return "Authorization failed: \(msg)"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        case .invalidResponse(let code, let body):
            return "HTTP \(code): \(body ?? "no body")"
        case .decodingFailed(let err):
            return "Decoding failed: \(err.localizedDescription)"
        case .encodingFailed(let err):
            return "Encoding failed: \(err.localizedDescription)"
        case .providerUnsupported(let cap):
            return "Provider does not support: \(cap)"
        case .providerTypeMismatch(let expected, let actual):
            return "Provider type mismatch: expected \(expected), got \(actual)"
        case .toolExecutionFailed(let name, let err):
            return "Tool '\(name)' failed: \(err.localizedDescription)"
        case .toolNotFound(let name):
            return "Tool not found: '\(name)'"
        case .recipeRenderingFailed(let id, let keys):
            return "Recipe '\(id)' missing keys: \(keys.joined(separator: ", "))"
        case .recipeNotFound(let id):
            return "Recipe not found: '\(id)'"
        case .skillNotFound(let id):
            return "Skill not found: '\(id)'"
        case .requestBuildingFailed(let msg):
            return "Invalid request: \(msg)"
        case .rateLimitExceeded(let after):
            let suffix = after.map { ". Retry after \($0)s" } ?? ""
            return "Rate limit exceeded\(suffix)"
        case .contextLengthExceeded:
            return "Request exceeded the model's context window."
        case .invalidModel(let id):
            return "Invalid model: '\(id)'"
        case .inferenceFailed(let err):
            return "Inference failed: \(err.localizedDescription)"
        case .cancelled:
            return "The operation was cancelled."
        }
    }
}
