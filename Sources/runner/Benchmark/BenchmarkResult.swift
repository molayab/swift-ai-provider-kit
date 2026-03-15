import Foundation

// MARK: - Per-run sample

struct BenchmarkSample {
    let duration: TimeInterval     // seconds
    let inputTokens: Int
    let outputTokens: Int
}

// MARK: - Aggregated stats over N runs

struct BenchmarkStats {
    let name: String
    let samples: [BenchmarkSample]

    var count: Int { samples.count }

    var meanDuration: TimeInterval   { samples.map(\.duration).mean }
    var minDuration:  TimeInterval   { samples.map(\.duration).min() ?? 0 }
    var maxDuration:  TimeInterval   { samples.map(\.duration).max() ?? 0 }

    /// Output tokens per second (using mean duration).
    var tokensPerSecond: Double {
        let mean = samples.map { Double($0.outputTokens) }.mean
        guard meanDuration > 0 else { return 0 }
        return mean / meanDuration
    }

    var meanInputTokens:  Double { samples.map { Double($0.inputTokens)  }.mean }
    var meanOutputTokens: Double { samples.map { Double($0.outputTokens) }.mean }
}

// MARK: - Array helpers

private extension Array where Element == Double {
    var mean: Double { isEmpty ? 0 : reduce(0, +) / Double(count) }
}
