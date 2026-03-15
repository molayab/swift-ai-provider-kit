import AIProviderKit
import Foundation

/// An `AIProvider` implementation targeting the OpenAI Chat Completions API.
///
/// Supports text, vision, tool use (function calling), system prompts, and SSE streaming.
///
/// ```swift
/// let provider = OpenAIProvider(
///     authorization: BearerAuthorization(apiKey: "<OPENAI_API_KEY>"),
/// )
/// let client = AIClient(provider: provider)
/// ```
public final class OpenAIProvider: StreamableProvider, ModelDiscoveryProvider {

    // MARK: - Constants

    private static let baseURL = OpenAIConstants.chatCompletionsURL
    private static let modelsURL = OpenAIConstants.modelsURL

    // MARK: - AIProvider

    public let identifier = "openai"
    public let capabilities: Set<AICapability> = [.text, .vision, .tools, .streaming, .systemPrompt, .modelDiscovery]

    // MARK: - Dependencies

    private let authorization: any AuthorizationProvider
    private let httpClient: any HTTPClient
    private let requestMapper: OpenAIRequestMapper
    private let responseMapper: OpenAIResponseMapper
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
        requestMapper: OpenAIRequestMapper = OpenAIRequestMapper(),
        responseMapper: OpenAIResponseMapper = OpenAIResponseMapper(),
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
        let openAIRequest = requestMapper.map(request, stream: false)
        let httpRequest = try await buildHTTPRequest(body: openAIRequest)

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
            let openAIResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: httpResponse.body)
            return responseMapper.map(openAIResponse)
        } catch {
            throw AIError.decodingFailed(underlying: error)
        }
    }

    // MARK: - StreamableProvider

    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let openAIRequest = self.requestMapper.map(request, stream: true)
                    let httpRequest = try await self.buildHTTPRequest(body: openAIRequest)

                    // Accumulator state for the final .message event
                    var messageId = ""
                    var messageModel = request.model.identifier
                    var stopReason = StopReason.unknown
                    var textBuffer = ""
                    var inputTokens = 0
                    var outputTokens = 0
                    // tool_calls by index: (id, name, accumulated arguments JSON)
                    var toolAccumulators: [Int: (id: String, name: String, arguments: String)] = [:]

                    for try await data in self.httpClient.stream(httpRequest) {
                        let chunk = try self.responseMapper.decodeStreamChunk(data)

                        if let id = chunk.id, !id.isEmpty { messageId = id }
                        if let model = chunk.model, !model.isEmpty { messageModel = model }

                        // Final usage-only chunk sent when stream_options.include_usage is true
                        if let usage = chunk.usage {
                            inputTokens = usage.promptTokens
                            outputTokens = usage.completionTokens
                        }

                        guard let choice = chunk.choices.first else { continue }

                        if let reason = choice.finishReason {
                            stopReason = self.responseMapper.mapFinishReason(reason)
                        }

                        let delta = choice.delta
                        if let text = delta.content, !text.isEmpty {
                            textBuffer += text
                            continuation.yield(.textDelta(text))
                        }

                        if let toolCallDeltas = delta.toolCalls {
                            for tc in toolCallDeltas {
                                let idx = tc.index
                                var acc = toolAccumulators[idx] ?? (id: "", name: "", arguments: "")
                                if let newId = tc.id, !newId.isEmpty { acc.id = newId }
                                if let newName = tc.function?.name, !newName.isEmpty { acc.name = newName }
                                let argsDelta = tc.function?.arguments ?? ""
                                acc.arguments += argsDelta
                                toolAccumulators[idx] = acc
                                if !argsDelta.isEmpty {
                                    continuation.yield(.toolUseDelta(id: acc.id, name: acc.name, inputDelta: argsDelta))
                                }
                            }
                        }
                    }

                    // Assemble final AIResponse from accumulated state
                    var content: [ContentBlock] = []
                    if !textBuffer.isEmpty {
                        content.append(.text(textBuffer))
                    }
                    for index in toolAccumulators.keys.sorted() {
                        let acc = toolAccumulators[index]!
                        let inputData = acc.arguments.data(using: .utf8) ?? Data()
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

    // MARK: - ModelDiscoveryProvider

    /// Fetches all chat-capable models available to the current API key.
    ///
    /// The OpenAI `/v1/models` endpoint returns every model type (embeddings, TTS,
    /// DALL-E, Whisper, …). This method filters the list down to models that are
    /// known to work with the Chat Completions API by excluding non-chat prefixes
    /// and legacy models.
    ///
    /// ```swift
    /// let models = try await provider.listModels()
    /// // [AIModelInfo(model: AIModel("gpt-4o"), …), …]
    /// ```
    public func listModels() async throws(AIError) -> [AIModelInfo] {
        var headers = try await authorization.authorizationHeaders()
        headers["content-type"] = "application/json"

        let httpRequest = HTTPRequest(method: "GET", url: Self.modelsURL, headers: headers, body: nil)

        let httpResponse: HTTPResponse
        do {
            httpResponse = try await httpClient.send(httpRequest)
        } catch let urlError as URLError {
            throw AIError.networkError(urlError)
        } catch {
            throw AIError.networkError(URLError(.unknown))
        }

        try validateStatus(httpResponse)

        let listResponse: OpenAIModelListResponse
        do {
            listResponse = try JSONDecoder().decode(OpenAIModelListResponse.self, from: httpResponse.body)
        } catch {
            throw AIError.decodingFailed(underlying: error)
        }

        return listResponse.data
            .filter(isChatModel)
            .map { object in
                let date = Date(timeIntervalSince1970: TimeInterval(object.created))
                return AIModelInfo(model: AIModel(object.id), displayName: nil, createdAt: date)
            }
    }

    // MARK: - Private helpers

    private func buildHTTPRequest<Body: Encodable>(body: Body) async throws(AIError) -> HTTPRequest {
        var headers = try await authorization.authorizationHeaders()
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

    /// Returns `true` for models compatible with the Chat Completions API.
    ///
    /// Consults `OpenAIConstants.chatModelPrefixes` and `OpenAIConstants.excludedModelPrefixes`
    /// — update those lists when OpenAI ships new model families.
    private func isChatModel(_ object: OpenAIModelObject) -> Bool {
        let id = object.id
        let isExcluded = OpenAIConstants.excludedModelPrefixes.contains { id.hasPrefix($0) }
        let isChat = OpenAIConstants.chatModelPrefixes.contains { id.hasPrefix($0) }
        return isChat && !isExcluded
    }

    private func validateStatus(_ response: HTTPResponse) throws(AIError) {
        guard !(200...299).contains(response.statusCode) else { return }

        let body = String(data: response.body, encoding: .utf8)

        if response.statusCode == 429 {
            throw AIError.rateLimitExceeded(retryAfter: nil)
        }

        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: response.body) {
            let code = errorResponse.error.code ?? ""
            let isContextError = code == "context_length_exceeded"
                || errorResponse.error.message.lowercased().contains("context length")
            if isContextError {
                throw AIError.contextLengthExceeded
            }

            if code == "model_not_found" {
                throw AIError.invalidModel(errorResponse.error.message)
            }
        }

        throw AIError.invalidResponse(statusCode: response.statusCode, body: body)
    }
}

// MARK: - Model Constants

public extension AIModel {
    /// GPT-4o — OpenAI's multimodal flagship.
    static let gpt4o = AIModel("gpt-4o")
    /// GPT-4o Mini — smaller, faster, cheaper variant of GPT-4o.
    static let gpt4oMini = AIModel("gpt-4o-mini")
    /// o1 — reasoning-optimised model.
    static let o1 = AIModel("o1")
    /// o3-mini — compact reasoning model.
    static let o3Mini = AIModel("o3-mini")
    /// o4-mini — latest compact reasoning model.
    static let o4Mini = AIModel("o4-mini")
}
