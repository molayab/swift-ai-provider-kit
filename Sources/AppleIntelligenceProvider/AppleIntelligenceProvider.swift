import AIProviderKit

/// An `AIProvider` implementation using Apple's on-device Foundation Models framework.
///
/// Requires iOS 26+ / macOS 26+ with Apple Intelligence enabled.
/// Check `AppleIntelligenceAvailability.isAvailable` before instantiating this provider.
///
/// ```swift
/// guard AppleIntelligenceAvailability.isAvailable else {
///     // Fall back to a remote provider such as ClaudeProvider
///     return
/// }
/// let provider = AppleIntelligenceProvider()
/// let client = AIClient(provider: provider)
/// ```
///
/// ## Capabilities
/// | Capability     | Supported |
/// |----------------|-----------|
/// | `.text`        | ✅        |
/// | `.streaming`   | ✅        |
/// | `.systemPrompt`| ✅        |
/// | `.tools`       | ✅ native via `FMToolBridge` / `FoundationModels.Tool` |
/// | `.vision`      | ❌        |
public final class AppleIntelligenceProvider: StreamableProvider {

    // MARK: - AIProvider

    public let identifier = "apple-intelligence"

    public let capabilities: Set<AICapability> = [.text, .streaming, .systemPrompt, .tools]

    // MARK: - Dependencies

    private let sessionFactory: any FMSessionFactory
    private let requestMapper: FMRequestMapper
    private let responseMapper: FMResponseMapper
    private let logger: AILogger?

    // MARK: - Init

    /// Creates a provider backed by the on-device Apple Intelligence runtime.
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

    public func send(_ request: AIRequest) async throws(AIError) -> AIResponse {
        let modelId = request.model.identifier
        logger?.info("AppleIntelligenceProvider: send — model=\(modelId)")

        let fmRequest = requestMapper.map(request)
        let session = try sessionFactory.makeSession(for: fmRequest)

        let fmResponse: FMResponse
        do {
            fmResponse = try await session.respond(to: fmRequest)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.inferenceFailed(underlying: error)
        }

        let response = responseMapper.map(fmResponse, model: modelId)
        logger?.info("AppleIntelligenceProvider: received response — stopReason=\(response.stopReason.rawValue)")
        return response
    }

    // MARK: - StreamableProvider

    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let modelId = request.model.identifier
                    self.logger?.info("AppleIntelligenceProvider: stream — model=\(modelId)")

                    let fmRequest = self.requestMapper.map(request)
                    let session = try self.sessionFactory.makeSession(for: fmRequest)

                    var accumulated = ""
                    for try await delta in session.stream(fmRequest) {
                        if Task.isCancelled { break }
                        accumulated += delta.text
                        continuation.yield(self.responseMapper.mapStreamDelta(delta))
                    }

                    guard !Task.isCancelled else {
                        continuation.finish()
                        return
                    }

                    // Emit a final .message event so consumers (BenchmarkSuite,
                    // AIClient tool-use loop) receive the complete response + token estimates.
                    let finalResponse = self.responseMapper.mapStreamFinal(accumulated, model: modelId)
                    continuation.yield(.message(finalResponse))
                    continuation.finish()
                } catch {
                    self.logger?.error("AppleIntelligenceProvider: stream error — \(error)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }
}

// MARK: - Model Constants

public extension AIModel {
    /// The default on-device Apple Intelligence model.
    static let appleIntelligenceDefault = AIModel("com.apple.foundation-models.default")
}
