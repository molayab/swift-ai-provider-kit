import AIProviderKit

/// Authenticates via a static API key sent in the `x-api-key` header.
///
/// This is the standard authentication method for the Anthropic Messages API.
///
/// ```swift
/// let auth = APIKeyAuthorization(apiKey: "sk-ant-...")
/// ```
public struct APIKeyAuthorization: AuthorizationProvider {

    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func authorizationHeaders() async throws -> [String: String] {
        guard !apiKey.isEmpty else {
            throw AIError.authorizationFailed("API key must not be empty.")
        }
        return ["x-api-key": apiKey]
    }
}
