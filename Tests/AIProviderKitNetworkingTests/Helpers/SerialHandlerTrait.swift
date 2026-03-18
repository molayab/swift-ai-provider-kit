import Testing

/// Actor-based binary semaphore used to serialize test bodies that share
/// `MockURLProtocol.requestHandler` (a process-wide global required by URLProtocol).
///
/// Each `URLSessionHTTPClientTests` instance acquires the semaphore in `init()` and
/// releases it in `deinit`, guaranteeing at most one test body runs at a time.
actor HandlerSemaphore {
    static let shared = HandlerSemaphore()
    private var occupied = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        guard occupied else {
            occupied = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            occupied = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
