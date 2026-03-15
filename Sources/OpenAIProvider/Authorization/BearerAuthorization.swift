import AIProviderKit

/// Authenticates via a Bearer token sent in the `Authorization` header.
///
/// This is the standard authentication method for the OpenAI API.
///
/// ```swift
/// let auth = BearerAuthorization(apiKey: "sk-...")
/// let provider = OpenAIProvider(authorization: auth)
/// ```
public struct BearerAuthorization: AuthorizationProvider {

    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func authorizationHeaders() async throws(AIError) -> [String: String] {
        guard !apiKey.isEmpty else {
            throw AIError.authorizationFailed("API key must not be empty.")
        }
        return ["Authorization": "Bearer \(apiKey)"]
    }
}
