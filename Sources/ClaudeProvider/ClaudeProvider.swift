import AIProviderKit
import AIProviderKitNetworking
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
public final class ClaudeProvider: StreamableProvider, ModelDiscoveryProvider {

    // MARK: - Constants

    private static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let modelsURL = URL(string: "https://api.anthropic.com/v1/models")!
    private static let anthropicVersion = "2023-06-01"

    // MARK: - AIProvider

    public let identifier = "claude"
    public let capabilities: Set<AICapability> = [.text, .vision, .tools, .streaming, .systemPrompt, .modelDiscovery]

    public func canHandle(model: AIModel) -> Bool { ClaudeModel.handles(model) }

    // MARK: - Dependencies

    private let authorization: any AuthorizationProvider
    private let httpClient: any HTTPClient
    private let requestMapper: ClaudeRequestMapper
    private let responseMapper: ClaudeResponseMapper
    private let logger: AILogger?

    // MARK: - Init

    /// Creates a provider using a caller-supplied `HTTPClient`.
    ///
    /// Use this initialiser on Linux, Windows, or whenever you need to substitute a
    /// custom networking backend (e.g. one built on SwiftNIO's `AsyncHTTPClient`).
    public convenience init(
        authorization: any AuthorizationProvider,
        httpClient: any HTTPClient,
        logger: AILogger? = nil
    ) {
        self.init(
            authorization: authorization,
            httpClient: httpClient,
            requestMapper: ClaudeRequestMapper(),
            responseMapper: ClaudeResponseMapper(),
            logger: logger
        )
    }

    #if canImport(Darwin)
    /// Creates a provider using the default `URLSessionHTTPClient` backend.
    ///
    /// Available on Apple platforms only. On Linux or Windows use
    /// `init(authorization:httpClient:logger:)` and supply an alternative backend.
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
    #endif

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

                    var state = self.responseMapper.makeStreamState(
                        fallbackModel: request.model.identifier
                    )
                    for try await data in self.httpClient.stream(httpRequest) {
                        let event = try self.responseMapper.decodeStreamEvent(data)
                        for streamEvent in try self.responseMapper.processStreamEvent(event, state: &state) {
                            continuation.yield(streamEvent)
                        }
                    }

                    continuation.yield(.message(self.responseMapper.finalizeStream(state)))
                    continuation.finish()
                } catch {
                    self.handleStreamError(error, continuation: continuation)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - ModelDiscoveryProvider

    public func listModels() async throws(AIError) -> [AIModelInfo] {
        var accumulated: [AIModelInfo] = []
        var afterId: String?

        repeat {
            guard !Task.isCancelled else { throw AIError.networkError(URLError(.cancelled)) }

            guard var components = URLComponents(url: Self.modelsURL, resolvingAgainstBaseURL: false) else {
                throw AIError.encodingFailed(underlying: URLError(.badURL))
            }
            if let cursor = afterId {
                components.queryItems = [URLQueryItem(name: "after_id", value: cursor)]
            }
            guard let url = components.url else {
                throw AIError.encodingFailed(underlying: URLError(.badURL))
            }

            let httpRequest = try await buildGETRequest(url: url)

            let httpResponse: HTTPResponse
            do {
                httpResponse = try await httpClient.send(httpRequest)
            } catch let urlError as URLError {
                throw AIError.networkError(urlError)
            } catch {
                throw AIError.networkError(URLError(.unknown))
            }

            try validateStatus(httpResponse)

            let page: ClaudeModelListResponse
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                page = try decoder.decode(ClaudeModelListResponse.self, from: httpResponse.body)
            } catch {
                throw AIError.decodingFailed(underlying: error)
            }

            let models = page.data.map { object in
                AIModelInfo(model: AIModel(object.id), displayName: object.displayName, createdAt: object.createdAt)
            }
            accumulated.append(contentsOf: models)
            afterId = page.hasMore ? page.lastId : nil
        } while afterId != nil

        return accumulated
    }

    // MARK: - Private helpers

    private func buildBaseHeaders() async throws(AIError) -> [String: String] {
        var headers = try await authorization.authorizationHeaders()
        headers["anthropic-version"] = Self.anthropicVersion
        return headers
    }

    private func buildGETRequest(url: URL) async throws(AIError) -> HTTPRequest {
        return HTTPRequest(method: "GET", url: url, headers: try await buildBaseHeaders(), body: nil)
    }

    private func buildHTTPRequest<Body: Encodable>(body: Body) async throws(AIError) -> HTTPRequest {
        var headers = try await buildBaseHeaders()
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

// MARK: - Stream helpers

private extension ClaudeProvider {

    func handleStreamError(
        _ error: any Error,
        continuation: AsyncThrowingStream<AIStreamEvent, any Error>.Continuation
    ) {
        guard let streamError = error as? HTTPStreamError else {
            continuation.finish(throwing: error)
            return
        }
        let response = HTTPResponse(statusCode: streamError.statusCode, body: streamError.body)
        do {
            try validateStatus(response)
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }
}
