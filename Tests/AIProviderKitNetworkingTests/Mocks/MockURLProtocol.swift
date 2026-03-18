import Foundation
import os

/// `URLProtocol` subclass that intercepts all `URLSession` requests in tests.
///
/// Set `requestHandler` before each test and inject a session built by `makeSession()`.
/// Works for both `data(for:)` and `bytes(for:)`.
///
/// **Thread safety:** `requestHandler` is protected by an `OSAllocatedUnfairLock` so it is
/// safe to read from the URL loading system's background threads while test code (running on
/// Swift concurrency executors) writes it. Per-instance cancellation state is protected by a
/// separate instance-level lock.
///
/// **Delivery model:** data is streamed in 64-byte chunks on a detached thread so that
/// `stopLoading()` can interrupt delivery mid-stream. This supports cancellation tests that
/// need the stream to still be in-flight when the consumer task is cancelled.
///
/// Marked `@unchecked Sendable` because the class carries no mutable state beyond what is
/// protected by the two `OSAllocatedUnfairLock` instances.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    // MARK: - Static handler (test-supplied)

    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let handlerLock = OSAllocatedUnfairLock<Handler?>(initialState: nil)

    static var requestHandler: Handler? {
        get { handlerLock.withLock { $0 } }
        set { handlerLock.withLock { $0 = newValue } }
    }

    // MARK: - Per-instance cancellation

    private let cancelLock = OSAllocatedUnfairLock(initialState: false)

    private var isCancelled: Bool {
        get { cancelLock.withLock { $0 } }
        set { cancelLock.withLock { $0 = newValue } }
    }

    // MARK: - URLProtocol

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        // Deliver on a detached thread so stopLoading() can interrupt chunked delivery.
        Thread.detachNewThread { [weak self] in
            guard let self else { return }
            do {
                let (response, data) = try handler(self.request)
                guard !self.isCancelled else { return }
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                // Stream data in small chunks; check cancellation between each chunk.
                var offset = 0
                while offset < data.count {
                    if self.isCancelled {
                        self.client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
                        return
                    }
                    let end = min(offset + 64, data.count)
                    self.client?.urlProtocol(self, didLoad: data[offset..<end])
                    offset = end
                }
                guard !self.isCancelled else { return }
                self.client?.urlProtocolDidFinishLoading(self)
            } catch {
                self.client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        isCancelled = true
    }

    // MARK: - Helpers

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
