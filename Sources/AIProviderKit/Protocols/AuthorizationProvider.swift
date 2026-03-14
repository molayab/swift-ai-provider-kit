/// Supplies authorization headers for outgoing API requests.
///
/// Implement this protocol to support different auth strategies
/// (API key, Bearer token, OAuth, etc.) without changing provider code.
public protocol AuthorizationProvider: Sendable {

    /// Returns HTTP headers required to authenticate the request.
    func authorizationHeaders() async throws -> [String: String]

    /// Called when the current credentials are rejected (e.g. 401).
    /// Default implementation is a no-op; override to refresh tokens.
    func refresh() async throws
}

public extension AuthorizationProvider {
    // swiftlint:disable:next async_without_await unneeded_throws_rethrows
    func refresh() async throws {}
}
