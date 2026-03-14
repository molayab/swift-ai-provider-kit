/// Supplies authorization headers for outgoing API requests.
///
/// Implement this protocol to support different auth strategies
/// (API key, Bearer token, OAuth, etc.) without changing provider code.
public protocol AuthorizationProvider: Sendable {

    /// Returns HTTP headers required to authenticate the request.
    func authorizationHeaders() async throws(AIError) -> [String: String]

    /// Called when the current credentials are rejected (e.g. 401).
    /// Default implementation is a no-op; override to refresh tokens.
    func refresh() async throws
}

public extension AuthorizationProvider {
    func refresh() async throws {}
}
