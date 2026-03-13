#if canImport(FoundationModels)
import FoundationModels
#endif
import AIProviderKit

/// The production `FMSessionFactory`.
///
/// Returns a `LiveFMSession` when `FoundationModels` is available and a capable
/// device is detected at runtime. Otherwise throws `AIError.providerUnsupported`.
struct DefaultFMSessionFactory: FMSessionFactory {

    func makeSession(for request: FMRequest) throws(AIError) -> any FMSessionProtocol {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else {
                throw AIError.providerUnsupported(capability: .text)
            }
            do {
                return try LiveFMSession(request: request)
            } catch {
                throw AIError.requestBuildingFailed("Invalid tool schema: \(error.localizedDescription)")
            }
        } else {
            throw AIError.providerUnsupported(capability: .text)
        }
        #else
        throw AIError.providerUnsupported(capability: .text)
        #endif
    }
}

// MARK: - Live Session

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
final class LiveFMSession: FMSessionProtocol, @unchecked Sendable {

    private let session: LanguageModelSession

    /// - Throws: `GenerationSchema.SchemaError` if any tool's `inputSchema` is invalid.
    init(request: FMRequest) throws {
        // Build native FMToolBridge instances so the model can call tools directly
        // during inference — no prompt injection needed.
        let toolBridges: [any FoundationModels.Tool] = try request.tools.map { toolDef in
            try FMToolBridge(
                name: toolDef.name,
                description: toolDef.description,
                inputSchema: toolDef.inputSchema,
                handler: toolDef.handler
            )
        }

        if let prompt = request.systemPrompt, !prompt.isEmpty {
            session = LanguageModelSession(tools: toolBridges, instructions: Instructions(prompt))
        } else {
            session = LanguageModelSession(tools: toolBridges)
        }
    }

    // MARK: - FMSessionProtocol

    func respond(to request: FMRequest) async throws -> FMResponse {
        let prompt = buildPrompt(from: request)
        // With tools registered, the session calls them automatically during inference.
        // `respond(to:)` returns only after all tool calls are resolved.
        let response = try await session.respond(to: prompt)
        return FMResponse(
            content: response.content,
            toolCalls: [],
            stopReason: .endTurn
        )
    }

    func stream(_ request: FMRequest) -> AsyncThrowingStream<FMStreamDelta, any Error> {
        let prompt = buildPrompt(from: request)
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // `Snapshot.content` is `String.PartiallyGenerated == String` —
                    // each snapshot holds the full accumulated text; compute deltas manually.
                    var previousLength = 0
                    for try await snapshot in session.streamResponse(to: prompt) {
                        let accumulated: String = snapshot.content
                        guard accumulated.count > previousLength else { continue }
                        let startIndex = accumulated.index(accumulated.startIndex, offsetBy: previousLength)
                        let delta = String(accumulated[startIndex...])
                        previousLength = accumulated.count
                        if !delta.isEmpty {
                            continuation.yield(FMStreamDelta(text: delta))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func buildPrompt(from request: FMRequest) -> String {
        request.messages.last?.content ?? ""
    }
}
#endif
