@testable import AIProviderKitNetworking
import Foundation
import os
import Testing

/// Thread-safe capture box for values written from a `@Sendable` closure on a
/// background thread and read from an async test context. The internal
/// `OSAllocatedUnfairLock` provides the synchronization that justifies
/// `@unchecked Sendable`. Each test owns its own instance.
final class SendableCapture<T: Sendable>: @unchecked Sendable {
    private let _lock = OSAllocatedUnfairLock<T?>(initialState: nil)

    var value: T? { _lock.withLock { $0 } }

    func set(_ newValue: T) {
        _lock.withLock { $0 = newValue }
    }
}

// Tests share MockURLProtocol.requestHandler (a process-wide global required by the
// URLProtocol API). Using a class suite with async init/deinit ensures at most one test
// body runs at a time via HandlerSemaphore, preventing handler cross-contamination.
//
// Note: @Suite(.serialized) only serializes *parameterized* test cases and has no effect
// on regular tests. The class init()/deinit pattern is the correct Swift Testing idiom
// for per-test setUp/tearDown with shared mutable state.
//
// The OSAllocatedUnfairLock inside MockURLProtocol additionally guards the handler
// against concurrent reads from the URL loading system's background threads.
@Suite("URLSessionHTTPClient", .tags(.networking))
final class URLSessionHTTPClientTests {

    init() async {
        await HandlerSemaphore.shared.acquire()
    }

    deinit {
        Task { await HandlerSemaphore.shared.release() }
    }

    private static let testURL = URL(string: "https://example.com/test")!

    // MARK: - send(_:)

    @Test("send returns status code and body on 2xx")
    func sendHappyPath() async throws {
        // given
        let expectedBody = Data(#"{"result":"ok"}"#.utf8)
        MockURLProtocol.requestHandler = { _ in
            (.init(url: Self.testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!, expectedBody)
        }
        let sut = URLSessionHTTPClient(session: MockURLProtocol.makeSession())
        let request = HTTPRequest(method: "POST", url: Self.testURL, headers: [:], body: nil)

        // when
        let response = try await sut.send(request)

        // then
        #expect(response.statusCode == 200)
        #expect(response.body == expectedBody)
    }

    @Test("send forwards request method and headers")
    func sendForwardsRequestMetadata() async throws {
        // given
        // SendableCapture boxes the URLRequest so it can be written from the @Sendable
        // handler (background thread) and read after the await completes (happens-before).
        let capture = SendableCapture<URLRequest>()
        MockURLProtocol.requestHandler = { request in
            capture.set(request)
            return (.init(url: Self.testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        let sut = URLSessionHTTPClient(session: MockURLProtocol.makeSession())
        let request = HTTPRequest(
            method: "POST",
            url: Self.testURL,
            headers: ["content-type": "application/json", "x-api-key": "test-key"],
            body: Data(#"{"hello":"world"}"#.utf8)
        )

        // when
        _ = try await sut.send(request)
        let capturedRequest = try #require(capture.value)

        // then
        #expect(capturedRequest.httpMethod == "POST")
        #expect(capturedRequest.value(forHTTPHeaderField: "content-type") == "application/json")
        #expect(capturedRequest.value(forHTTPHeaderField: "x-api-key") == "test-key")
        // URLProtocol converts httpBody to httpBodyStream internally; read from whichever is set
        let bodyData = capturedRequest.httpBody ?? capturedRequest.httpBodyStream.flatMap { stream in
            var data = Data()
            stream.open()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
            defer { buffer.deallocate(); stream.close() }
            while stream.hasBytesAvailable {
                let count = stream.read(buffer, maxLength: 1024)
                if count > 0 { data.append(buffer, count: count) }
            }
            return data
        }
        #expect(bodyData == request.body)
    }

    @Test("send passes through non-2xx status codes without throwing")
    func sendPassesThroughNonSuccessStatus() async throws {
        // given
        let errorBody = Data(#"{"error":"not found"}"#.utf8)
        MockURLProtocol.requestHandler = { _ in
            (.init(url: Self.testURL, statusCode: 404, httpVersion: nil, headerFields: nil)!, errorBody)
        }
        let sut = URLSessionHTTPClient(session: MockURLProtocol.makeSession())
        let request = HTTPRequest(method: "GET", url: Self.testURL, headers: [:], body: nil)

        // when
        let response = try await sut.send(request)

        // then — status mapping is provider responsibility, client just returns what it receives
        #expect(response.statusCode == 404)
        #expect(response.body == errorBody)
    }

    @Test("send propagates URLError on network failure")
    func sendPropagatesNetworkError() async {
        // given
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let sut = URLSessionHTTPClient(session: MockURLProtocol.makeSession())
        let request = HTTPRequest(method: "GET", url: Self.testURL, headers: [:], body: nil)

        // when / then
        await #expect(throws: URLError.self) {
            _ = try await sut.send(request)
        }
    }

    // MARK: - stream(_:)

    @Test("stream strips data: prefix and yields payloads")
    func streamStripsSsePrefix() async throws {
        // given — two SSE lines followed by [DONE]
        let sseBody = Data("data: {\"id\":1}\ndata: {\"id\":2}\ndata: [DONE]\n".utf8)
        MockURLProtocol.requestHandler = { _ in
            (.init(url: Self.testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!, sseBody)
        }
        let sut = URLSessionHTTPClient(session: MockURLProtocol.makeSession())
        let request = HTTPRequest(method: "POST", url: Self.testURL, headers: [:], body: nil)

        // when
        var chunks: [Data] = []
        for try await chunk in sut.stream(request) {
            chunks.append(chunk)
        }

        // then
        #expect(chunks.count == 2)
        #expect(String(data: chunks[0], encoding: .utf8) == #"{"id":1}"#)
        #expect(String(data: chunks[1], encoding: .utf8) == #"{"id":2}"#)
    }

    @Test("stream ignores non-data lines")
    func streamIgnoresNonDataLines() async throws {
        // given — mixed SSE envelope lines
        let sseBody = Data("event: message_start\ndata: {\"ok\":true}\ndata: [DONE]\n".utf8)
        MockURLProtocol.requestHandler = { _ in
            (.init(url: Self.testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!, sseBody)
        }
        let sut = URLSessionHTTPClient(session: MockURLProtocol.makeSession())
        let request = HTTPRequest(method: "POST", url: Self.testURL, headers: [:], body: nil)

        // when
        var chunks: [Data] = []
        for try await chunk in sut.stream(request) {
            chunks.append(chunk)
        }

        // then — only the `data:` line is forwarded
        #expect(chunks.count == 1)
        #expect(String(data: chunks[0], encoding: .utf8) == #"{"ok":true}"#)
    }

    @Test("stream throws HTTPStreamError on non-2xx response")
    func streamThrowsOnNonSuccessStatus() async throws {
        // given
        let errorBody = Data(#"{"error":"unauthorized"}"#.utf8)
        MockURLProtocol.requestHandler = { _ in
            (.init(url: Self.testURL, statusCode: 401, httpVersion: nil, headerFields: nil)!, errorBody)
        }
        let sut = URLSessionHTTPClient(session: MockURLProtocol.makeSession())
        let request = HTTPRequest(method: "POST", url: Self.testURL, headers: [:], body: nil)

        // when / then
        await #expect(throws: HTTPStreamError.self) {
            for try await _ in sut.stream(request) {}
        }
    }

    @Test("stream HTTPStreamError carries status code and body")
    func streamErrorCarriesMetadata() async throws {
        // given
        let errorBody = Data(#"{"error":"rate limited"}"#.utf8)
        MockURLProtocol.requestHandler = { _ in
            (.init(url: Self.testURL, statusCode: 429, httpVersion: nil, headerFields: nil)!, errorBody)
        }
        let sut = URLSessionHTTPClient(session: MockURLProtocol.makeSession())
        let request = HTTPRequest(method: "POST", url: Self.testURL, headers: [:], body: nil)

        // when / then
        let caughtError = await #expect(throws: HTTPStreamError.self) {
            for try await _ in sut.stream(request) {}
        }
        #expect(caughtError?.statusCode == 429)
        #expect(caughtError?.body == errorBody)
    }

    @Test("stream inner task is cancelled when consumer breaks early")
    func streamEarlyBreakCancelsInnerTask() async throws {
        // given — 10 SSE events; consumer will break after the first.
        let sseBody = Data(String(repeating: "data: {\"n\":1}\n", count: 10).utf8)
        MockURLProtocol.requestHandler = { _ in
            (.init(url: Self.testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!, sseBody)
        }
        let sut = URLSessionHTTPClient(session: MockURLProtocol.makeSession())
        let request = HTTPRequest(method: "POST", url: Self.testURL, headers: [:], body: nil)

        // when — break after the first element. This exits the for-try-await loop, releasing
        // the AsyncThrowingStream iterator, which fires onTermination and cancels the inner
        // URLSession task. The test verifies the loop exits early (no hang, correct count).
        var count = 0
        for try await _ in sut.stream(request) {
            count += 1
            break
        }

        // then
        #expect(count == 1)
    }
}
