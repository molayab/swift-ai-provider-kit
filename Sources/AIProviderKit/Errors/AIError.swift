import Foundation

/// Errors thrown by AIProviderKit operations.
public enum AIError: Error, Sendable {
    case authorizationFailed(String)
    case networkError(URLError)
    case invalidResponse(statusCode: Int, body: String?)
    case decodingFailed(underlying: any Error)
    case encodingFailed(underlying: any Error)
    case providerUnsupported(capability: AICapability)
    case toolExecutionFailed(toolName: String, underlying: any Error)
    case toolNotFound(String)
    case recipeRenderingFailed(recipeId: String, missingKeys: [String])
    case recipeNotFound(String)
    case skillNotFound(String)
    case requestBuildingFailed(String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case contextLengthExceeded
    case invalidModel(String)
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
        }
    }
}
