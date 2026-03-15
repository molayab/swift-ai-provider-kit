import AIProviderKit
import Foundation

/// An `AIProvider` implementation targeting the Anthropic Messages API.
///
/// Supports text, vision, tool use, system prompts, and server-sent event streaming.
///
/// ```swift
/// let provider = ClaudeProvider(
///     authorization: APIKeyAuthorization(apiKey: "sk-ant-..."),
///     defaultModel: .claudeSonnet4
/// )
/// let client = AIClient(provider: provider)
/// ```
public final class ClaudeProvider: StreamableProvider {

    // MARK: - Constants

    private static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let anthropicVersion = "2023-06-01"

    // MARK: - AIProvider

    public let identifier = "claude"
    public let capabilities: Set<AICapability> = [.text, .vision, .tools, .streaming, .systemPrompt]

    // MARK: - Dependencies

    private let authorization: any AuthorizationProvider
    private let httpClient: any HTTPClient
    private let requestMapper: ClaudeRequestMapper
    private let responseMapper: ClaudeResponseMapper
    private let logger: AILogger?

    // MARK: - Init

    public convenience init(
        authorization: any AuthorizationProvider,
        logger: AILogger? = nil
    ) {
        self.init(
            authorization: authorization,
            httpClient: URLSessionHTTPClient(),
            logger: logger
        )
    }

    init(
        authorization: any AuthorizationProvider,
        httpClient: any HTTPClient,
        requestMapper: ClaudeRequestMapper = ClaudeRequestMapper(),
        responseMapper: ClaudeResponseMapper = ClaudeResponseMapper(),
        logger: AILogger? = nil
    ) {
        self.authorization = authorization
        self.httpClient = httpClient
        self.requestMapper = requestMapper
        self.responseMapper = responseMapper
        self.logger = logger
    }

    // MARK: - AIProvider

    public func send(_ request: AIRequest) async throws(AIError) -> AIResponse {
        let claudeRequest = requestMapper.map(request, stream: false)
        let httpRequest = try await buildHTTPRequest(body: claudeRequest)

        let httpResponse: HTTPResponse
        do {
            httpResponse = try await httpClient.send(httpRequest)
        } catch let urlError as URLError {
            throw AIError.networkError(urlError)
        } catch {
            throw AIError.networkError(URLError(.unknown))
        }

        try validateStatus(httpResponse)

        do {
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: httpResponse.body)
            return responseMapper.map(claudeResponse)
        } catch {
            throw AIError.decodingFailed(underlying: error)
        }
    }

    // MARK: - StreamableProvider

    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let claudeRequest = self.requestMapper.map(request, stream: true)
                    let httpRequest = try await self.buildHTTPRequest(body: claudeRequest)

                    var messageId = ""
                    var messageModel = request.model.identifier
                    var inputTokens = 0
                    var outputTokens = 0
                    var stopReason = StopReason.unknown
                    var textBuffer = ""
                    var toolAccumulators: [Int: ClaudeToolAccumulator] = [:]

                    for try await data in self.httpClient.stream(httpRequest) {
                        let event = try self.responseMapper.decodeStreamEvent(data)
                        switch event.type {
                        case "message_start":
                            messageId = event.message?.id ?? messageId
                            messageModel = event.message?.model ?? messageModel
                            inputTokens = event.message?.usage?.inputTokens ?? 0
                        case "content_block_start":
                            if let block = event.contentBlock, block.type == "tool_use",
                               let index = event.index, let id = block.id, let name = block.name {
                                toolAccumulators[index] = ClaudeToolAccumulator(id: id, name: name, json: "")
                            }
                        case "content_block_delta":
                            self.applyContentBlockDelta(
                                event: event,
                                textBuffer: &textBuffer,
                                toolAccumulators: &toolAccumulators,
                                continuation: continuation
                            )
                        case "message_delta":
                            stopReason = self.responseMapper.mapStopReason(event.delta?.stopReason)
                            outputTokens = event.usage?.outputTokens ?? 0
                        case "error":
                            let body = String(data: data, encoding: .utf8)
                            throw AIError.invalidResponse(statusCode: 529, body: body)
                        default:
                            break
                        }
                    }

                    let content = self.buildStreamContent(
                        textBuffer: textBuffer,
                        toolAccumulators: toolAccumulators
                    )
                    let response = AIResponse(
                        id: messageId,
                        model: messageModel,
                        content: content,
                        usage: TokenUsage(inputTokens: inputTokens, outputTokens: outputTokens),
                        stopReason: stopReason
                    )
                    continuation.yield(.message(response))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Private helpers

    private func buildHTTPRequest<Body: Encodable>(body: Body) async throws(AIError) -> HTTPRequest {
        var headers = try await authorization.authorizationHeaders()
        headers["anthropic-version"] = Self.anthropicVersion
        headers["content-type"] = "application/json"

        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(body)
        } catch {
            throw AIError.encodingFailed(underlying: error)
        }

        return HTTPRequest(
            method: "POST",
            url: Self.baseURL,
            headers: headers,
            body: bodyData
        )
    }

    private func validateStatus(_ response: HTTPResponse) throws(AIError) {
        guard !(200...299).contains(response.statusCode) else { return }

        let body = String(data: response.body, encoding: .utf8)

        if response.statusCode == 429 {
            throw AIError.rateLimitExceeded(retryAfter: nil)
        }

        if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: response.body),
           errorResponse.error.message.lowercased().contains("context") {
            throw AIError.contextLengthExceeded
        }

        throw AIError.invalidResponse(statusCode: response.statusCode, body: body)
    }
}

// MARK: - Internal types

private struct ClaudeToolAccumulator {
    var id: String
    var name: String
    var json: String
}

// MARK: - Stream helpers

private extension ClaudeProvider {

    func applyContentBlockDelta(
        event: ClaudeStreamEvent,
        textBuffer: inout String,
        toolAccumulators: inout [Int: ClaudeToolAccumulator],
        continuation: AsyncThrowingStream<AIStreamEvent, any Error>.Continuation
    ) {
        guard let delta = event.delta, let index = event.index else { return }
        if delta.type == "text_delta", let text = delta.text {
            textBuffer += text
            continuation.yield(.textDelta(text))
        } else if delta.type == "input_json_delta", let partial = delta.partialJson {
            var acc = toolAccumulators[index] ?? ClaudeToolAccumulator(id: "", name: "", json: "")
            acc.json += partial
            toolAccumulators[index] = acc
            continuation.yield(.toolUseDelta(id: acc.id, name: acc.name, inputDelta: partial))
        }
    }

    func buildStreamContent(
        textBuffer: String,
        toolAccumulators: [Int: ClaudeToolAccumulator]
    ) -> [ContentBlock] {
        var content: [ContentBlock] = []
        if !textBuffer.isEmpty {
            content.append(.text(textBuffer))
        }
        for index in toolAccumulators.keys.sorted() {
            let acc = toolAccumulators[index]!
            let inputData = acc.json.data(using: .utf8) ?? Data()
            let input = (try? JSONDecoder().decode(JSONValue.self, from: inputData)) ?? .object([:])
            content.append(.toolUse(.init(id: acc.id, name: acc.name, input: input)))
        }
        return content
    }
}

// MARK: - Model Constants

public extension AIModel {
    /// Claude Opus 4.6 — Anthropic's most intelligent model, built for complex tasks and agentic use.
    static let claudeOpus46 = AIModel("claude-opus-4-6")
    /// Claude Sonnet 4.6 — best balance of speed and intelligence with a 1M-token context window.
    static let claudeSonnet46 = AIModel("claude-sonnet-4-6")
    /// Claude Haiku 4.5 — fastest model with near-frontier intelligence and a 200k-token context window.
    static let claudeHaiku45 = AIModel("claude-haiku-4-5-20251001")
}
