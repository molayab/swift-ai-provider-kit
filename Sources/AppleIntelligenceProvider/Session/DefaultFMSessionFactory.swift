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
        // LanguageModelSession is stateful: it accumulates all turns in its internal
        // transcript. Pass only the latest user message; prior turns are already in
        // session.transcript from previous calls on this session instance.
        let prompt = latestUserPrompt(from: request)
        // With tools registered, the session calls them automatically during inference.
        // `respond(to:)` returns only after all tool calls are resolved.
        do {
            let response = try await session.respond(to: prompt)
            return FMResponse(
                content: response.content,
                toolCalls: [],
                stopReason: .endTurn
            )
        } catch {
            throw mapGenerationError(error)
        }
    }

    func stream(_ request: FMRequest) -> AsyncThrowingStream<FMStreamDelta, any Error> {
        let prompt = latestUserPrompt(from: request)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // `Snapshot.content` is `String.PartiallyGenerated == String` —
                    // each snapshot holds the full accumulated text; compute deltas manually.
                    // Track the previous endpoint as a String.Index so both the guard and
                    // the slice are O(1): endIndex is derived from the stored UTF-8 byte
                    // count, and subscripting with a pre-computed index needs no re-walk.
                    var previousIndex: String.Index?
                    for try await snapshot in session.streamResponse(to: prompt) {
                        if Task.isCancelled { break }
                        let accumulated: String = snapshot.content
                        let start = previousIndex ?? accumulated.startIndex
                        guard start < accumulated.endIndex else { continue }
                        let delta = String(accumulated[start...])
                        previousIndex = accumulated.endIndex
                        if !delta.isEmpty {
                            continuation.yield(FMStreamDelta(text: delta))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapGenerationError(error))
                }
            }
            // Cancel the inner task when the consumer stops iterating (break, task
            // cancellation, or stream going out of scope). finish() is idempotent so
            // no guard is needed if the task already finished naturally.
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    // MARK: - Private

    /// Returns the content of the latest user message.
    ///
    /// `LanguageModelSession` is stateful: every `respond(to:)` / `streamResponse(to:)`
    /// call appends both the prompt and the model response to the session's internal
    /// `transcript`, so the model always has full multi-turn context. Only the *current*
    /// user turn needs to be passed; replaying prior turns would double-count history.
    private func latestUserPrompt(from request: FMRequest) -> String {
        request.messages.last { $0.role == "user" }?.content
            ?? request.messages.last?.content
            ?? ""
    }

    /// Maps `LanguageModelSession.GenerationError.exceededContextWindowSize` to the
    /// provider-agnostic `AIError.contextLengthExceeded` so callers never need to import
    /// `FoundationModels` to handle context-overflow conditions. All other errors pass through.
    private func mapGenerationError(_ error: any Error) -> any Error {
        if let genError = error as? LanguageModelSession.GenerationError,
           case .exceededContextWindowSize = genError {
            return AIError.contextLengthExceeded
        }
        return error
    }
}
#endif
