import AIProviderKit

/// An `AIProvider` implementation using Apple's on-device Foundation Models framework.
///
/// Requires a device and OS version that supports Apple Intelligence
/// (`iOS 18.1+` / `macOS 15.1+`). Check `FoundationModelAvailability.isAvailable`
/// before instantiating this provider in production.
///
/// ```swift
/// guard FoundationModelAvailability.isAvailable else {
///     // Fall back to a remote provider such as ClaudeProvider
///     return
/// }
/// let provider = FoundationModelProvider()
/// let client = AIClient(provider: provider)
/// ```
///
/// ## Capabilities
/// | Capability     | Supported |
/// |----------------|-----------|
/// | `.text`        | ✅        |
/// | `.streaming`   | ✅        |
/// | `.systemPrompt`| ✅        |
/// | `.tools`       | ⚠️ injected as prompt context (native @Tool bridge is a future milestone) |
/// | `.vision`      | ❌        |
public final class FoundationModelProvider: StreamableProvider {

    // MARK: - AIProvider

    public let identifier = "foundation-models"

    public let capabilities: Set<AICapability> = [.text, .streaming, .systemPrompt, .tools]

    // MARK: - Dependencies

    private let sessionFactory: any FMSessionFactory
    private let requestMapper: FMRequestMapper
    private let responseMapper: FMResponseMapper
    private let logger: AILogger?

    // MARK: - Init

    /// Creates a provider backed by the on-device Foundation Models runtime.
    ///
    /// - Parameter logger: Optional `AILogger` for structured logging.
    public convenience init(logger: AILogger? = nil) {
        self.init(
            sessionFactory: DefaultFMSessionFactory(),
            requestMapper: FMRequestMapper(),
            responseMapper: FMResponseMapper(),
            logger: logger
        )
    }

    /// Designated initialiser — use the `convenience init` in production.
    /// The internal init is exposed for test injection only.
    init(
        sessionFactory: any FMSessionFactory,
        requestMapper: FMRequestMapper = FMRequestMapper(),
        responseMapper: FMResponseMapper = FMResponseMapper(),
        logger: AILogger? = nil
    ) {
        self.sessionFactory = sessionFactory
        self.requestMapper = requestMapper
        self.responseMapper = responseMapper
        self.logger = logger
    }

    // MARK: - AIProvider

    public func send(_ request: AIRequest) async throws -> AIResponse {
        let modelId = request.model.identifier
        logger?.info("FoundationModelProvider: send — model=\(modelId)")

        let fmRequest = requestMapper.map(request)
        let session = try sessionFactory.makeSession(for: fmRequest)
        let fmResponse = try await session.respond(to: fmRequest)

        let response = responseMapper.map(fmResponse, model: modelId)
        logger?.info("FoundationModelProvider: received response — stopReason=\(response.stopReason.rawValue)")
        return response
    }

    // MARK: - StreamableProvider

    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let modelId = request.model.identifier
                    self.logger?.info("FoundationModelProvider: stream — model=\(modelId)")

                    let fmRequest = self.requestMapper.map(request)
                    let session = try self.sessionFactory.makeSession(for: fmRequest)

                    for try await delta in session.stream(fmRequest) {
                        let event = self.responseMapper.mapStreamDelta(delta)
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    self.logger?.error("FoundationModelProvider: stream error — \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Model Constants

public extension AIModel {
    /// The default on-device Foundation Model.
    static let foundationModelsDefault = AIModel("com.apple.foundation-models.default")
}
