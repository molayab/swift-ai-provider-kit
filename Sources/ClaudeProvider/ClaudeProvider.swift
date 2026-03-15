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

                    // Accumulator state for the final .message event
                    var messageId = ""
                    var messageModel = request.model.identifier
                    var inputTokens = 0
                    var outputTokens = 0
                    var stopReason = StopReason.unknown
                    var textBuffer = ""
                    // tool_use blocks by block index: (id, name, accumulated input JSON)
                    var toolAccumulators: [Int: (id: String, name: String, json: String)] = [:]

                    for try await data in self.httpClient.stream(httpRequest) {
                        let event = try self.responseMapper.decodeStreamEvent(data)

                        switch event.type {
                        case "message_start":
                            messageId = event.message?.id ?? messageId
                            messageModel = event.message?.model ?? messageModel
                            inputTokens = event.message?.usage?.inputTokens ?? 0
                        case "content_block_start":
                            if let block = event.contentBlock,
                               block.type == "tool_use",
                               let index = event.index,
                               let id = block.id,
                               let name = block.name {
                                toolAccumulators[index] = (id: id, name: name, json: "")
                            }
                        case "content_block_delta":
                            guard let delta = event.delta, let index = event.index else { continue }
                            if delta.type == "text_delta", let text = delta.text {
                                textBuffer += text
                                continuation.yield(.textDelta(text))
                            } else if delta.type == "input_json_delta", let partial = delta.partialJson {
                                var acc = toolAccumulators[index] ?? (id: "", name: "", json: "")
                                acc.json += partial
                                toolAccumulators[index] = acc
                                continuation.yield(.toolUseDelta(id: acc.id, name: acc.name, inputDelta: partial))
                            }
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

                    // Assemble final AIResponse from accumulated state
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

// MARK: - Model Constants

public extension AIModel {
    static let claudeOpus4     = AIModel("claude-opus-4-6")
    static let claudeSonnet4   = AIModel("claude-sonnet-4-6")
    static let claudeHaiku4    = AIModel("claude-haiku-4-5-20251001")
}
