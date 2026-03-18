#if canImport(Darwin)
import Foundation

/// Production `HTTPClient` backed by `URLSession`.
///
/// Available on all Apple platforms (iOS, macOS, watchOS, tvOS, visionOS).
/// On Linux or Windows, initialise providers with an alternative `HTTPClient` conformer —
/// for example, one built on `AsyncHTTPClient` from SwiftNIO.
///
/// A private `URLSessionConfiguration` is used instead of `URLSession.shared` to:
/// - Avoid inheriting the host app's cookie and cache state (`ephemeral` base config)
/// - Support long-running SSE streams without hitting the default 60 s request timeout
/// - Enable `waitsForConnectivity` so requests queue rather than fail on flaky networks
///
/// Callers that need certificate pinning, a background session, or custom proxy settings
/// can inject their own `URLSession` instance via `init(session:)`.
///
/// Marked `@unchecked Sendable` because `URLSession` predates Swift concurrency
/// but is documented as safe to call from any concurrency domain.
public final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {

    private let session: URLSession

    public convenience init() {
        self.init(session: URLSessionHTTPClient.makeDefaultSession())
    }

    public init(session: URLSession) {
        self.session = session
    }

    // MARK: - HTTPClient

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest = makeURLRequest(from: request)
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return HTTPResponse(statusCode: http.statusCode, body: data)
    }

    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, any Error> {
        let (stream, continuation) = AsyncThrowingStream<Data, any Error>.makeStream()
        let task = Task {
            do {
                let urlRequest = makeURLRequest(from: request)
                let (bytes, urlResponse) = try await session.bytes(for: urlRequest)
                guard let http = urlResponse as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200...299).contains(http.statusCode) else {
                    var bodyData = Data()
                    for try await byte in bytes {
                        bodyData.append(byte)
                        if bodyData.count >= 8_192 { break }
                    }
                    throw HTTPStreamError(statusCode: http.statusCode, body: bodyData)
                }
                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let payload = String(line.dropFirst(6))
                    guard payload != "[DONE]" else { break }
                    continuation.yield(Data(payload.utf8))
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    // MARK: - Private

    private static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 300   // covers long streaming completions
        config.timeoutIntervalForResource = 600  // full budget for very large responses
        config.waitsForConnectivity = true        // queue rather than fail on flaky networks
        return URLSession(configuration: config)
    }

    private func makeURLRequest(from request: HTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        request.headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
        return urlRequest
    }
}
#endif
