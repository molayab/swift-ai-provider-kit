#if canImport(FoundationModels)
import FoundationModels
#endif
import AIProviderKit

/// The production `FMSessionFactory`.
///
/// On platforms where `FoundationModels` is available and a capable device is detected
/// at runtime, this returns a `LiveFMSession`. On all other platforms or devices it
/// throws `AIError.providerUnsupported(capability: .text)`.
struct DefaultFMSessionFactory: FMSessionFactory {

    func makeSession(for request: FMRequest) throws -> any FMSessionProtocol {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else {
                throw AIError.providerUnsupported(capability: .text)
            }
            return LiveFMSession(request: request)
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

    init(request: FMRequest) {
        // `Instructions` is a top-level FoundationModels type; String conforms to
        // `InstructionsRepresentable` so it can be passed directly.
        if let prompt = request.systemPrompt, !prompt.isEmpty {
            session = LanguageModelSession(instructions: Instructions(prompt))
        } else {
            session = LanguageModelSession()
        }
    }

    // MARK: - FMSessionProtocol

    func respond(to request: FMRequest) async throws -> FMResponse {
        let prompt = buildPrompt(from: request)
        // `respond(to: String)` returns `Response<String>` where `.content` is `String`.
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
                    // `Snapshot.content` is `String.PartiallyGenerated` which equals `String`
                    // since String's PartiallyGenerated defaults to Self.
                    // Each snapshot holds the full accumulated text — compute deltas manually.
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
        // Tool definitions are injected as prompt context because the FoundationModels
        // compile-time @Tool protocol cannot be dynamically bridged from AIProviderKit.Tool.
        // A native @Tool integration is tracked as a future milestone.
        var parts: [String] = []

        if !request.tools.isEmpty {
            let toolDescriptions = request.tools.map { tool in
                "- \(tool.name): \(tool.description)"
            }.joined(separator: "\n")
            parts.append("Available tools:\n\(toolDescriptions)")
        }

        if let lastMessage = request.messages.last {
            parts.append(lastMessage.content)
        }

        return parts.joined(separator: "\n\n")
    }
}
#endif
