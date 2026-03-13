/// A single Foundation Models inference session.
///
/// This protocol is the testability seam: production code uses `LiveFMSession`
/// (backed by `FoundationModels.LanguageModelSession`), while tests inject
/// `MockFMSession` without touching the system framework.
protocol FMSessionProtocol: Sendable {
    func respond(to request: FMRequest) async throws -> FMResponse
    func stream(_ request: FMRequest) -> AsyncThrowingStream<FMStreamDelta, any Error>
}

/// Creates `FMSessionProtocol` instances for each inference request.
///
/// Inject a `MockFMSessionFactory` in tests; the default `DefaultFMSessionFactory`
/// creates `LiveFMSession` instances backed by `FoundationModels.LanguageModelSession`.
protocol FMSessionFactory: Sendable {
    func makeSession(for request: FMRequest) throws -> any FMSessionProtocol
}
