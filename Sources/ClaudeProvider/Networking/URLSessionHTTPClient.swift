import Foundation

final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest = makeURLRequest(from: request)
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return HTTPResponse(statusCode: http.statusCode, body: data)
    }

    func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = self.makeURLRequest(from: request)
                    let (bytes, _) = try await self.session.bytes(for: urlRequest)
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard payload != "[DONE]" else { break }
                        if let data = payload.data(using: .utf8) {
                            continuation.yield(data)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeURLRequest(from request: HTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        request.headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
        return urlRequest
    }
}
