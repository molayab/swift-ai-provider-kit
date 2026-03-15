import Foundation

// MARK: - Per-run sample

struct BenchmarkSample {
    let duration: TimeInterval     // seconds — E2E latency or TTFT depending on scenario
    let ttft: TimeInterval?        // time-to-first-token (streaming scenarios only)
    let inputTokens: Int
    let outputTokens: Int          // may be estimated (char/4) when provider omits counts
    let tokensEstimated: Bool      // true when char/4 heuristic was used

    init(
        duration: TimeInterval,
        ttft: TimeInterval? = nil,
        inputTokens: Int,
        outputTokens: Int,
        tokensEstimated: Bool = false
    ) {
        self.duration        = duration
        self.ttft            = ttft
        self.inputTokens     = inputTokens
        self.outputTokens    = outputTokens
        self.tokensEstimated = tokensEstimated
    }
}

// MARK: - Aggregated stats over N runs

struct BenchmarkStats {
    let name: String
    let samples: [BenchmarkSample]

    var count: Int { samples.count }

    // MARK: Duration stats

    var meanDuration: TimeInterval { durations.mean }
    var medianDuration: TimeInterval { durations.median }
    var p95Duration: TimeInterval { durations.percentile(0.95) }
    var minDuration: TimeInterval { durations.min() ?? 0 }
    var maxDuration: TimeInterval { durations.max() ?? 0 }
    var stdDevDuration: TimeInterval { durations.stdDev }

    // MARK: TTFT stats (streaming scenarios)

    var meanTTFT: TimeInterval { ttfts.mean }
    var medianTTFT: TimeInterval { ttfts.median }
    var p95TTFT: TimeInterval { ttfts.percentile(0.95) }

    // MARK: Throughput

    /// Output tokens per second using median duration (more robust than mean).
    var tokensPerSecond: Double {
        guard medianDuration > 0 else { return 0 }
        return meanOutputTokens / medianDuration
    }

    /// Time Per Output Token (decode phase): (E2E - TTFT) / outputTokens.
    var tpot: TimeInterval {
        let validSamples = samples.compactMap { sample -> TimeInterval? in
            guard let ttft = sample.ttft, sample.outputTokens > 1 else { return nil }
            return (sample.duration - ttft) / Double(sample.outputTokens - 1)
        }
        return validSamples.mean
    }

    // MARK: Token usage

    var meanInputTokens: Double { samples.map { Double($0.inputTokens) }.mean }
    var meanOutputTokens: Double { samples.map { Double($0.outputTokens) }.mean }
    /// True when any sample used the char/4 heuristic instead of a provider-reported count.
    var tokensEstimated: Bool { samples.contains { $0.tokensEstimated } }

    // MARK: - Private helpers

    private var durations: [Double] { samples.map(\.duration) }
    private var ttfts: [Double] { samples.compactMap(\.ttft) }
}

// MARK: - Array statistical helpers

private extension Array where Element == Double {
    var mean: Double {
        isEmpty ? 0 : reduce(0, +) / Double(count)
    }

    var median: Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
    }

    func percentile(_ fraction: Double) -> Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let idx = Int((fraction * Double(sorted.count - 1)).rounded())
        return sorted[Swift.max(0, Swift.min(idx, sorted.count - 1))]
    }

    var stdDev: Double {
        guard count > 1 else { return 0 }
        let avg = mean
        let variance = map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(count - 1)
        return variance.squareRoot()
    }
}
