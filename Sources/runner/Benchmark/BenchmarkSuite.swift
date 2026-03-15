import Foundation
import AIProviderKit

/// Runs a set of latency and throughput benchmarks against any `AIClient`.
///
/// Methodology (aligned with MLPerf Inference and Swift Benchmark Package guidance):
/// - **Warm-up:** 3 discarded runs before measurement to prime the Neural Engine / model cache.
/// - **Measured runs:** 10 by default (override with `--runs N`).
/// - **Reported stats:** median (primary), mean, p95, min/max, std dev per scenario.
///
/// Four scenarios:
/// 1. **Non-streaming latency** — full round-trip (send → response). Primary: median.
/// 2. **Streaming TTFT** — time-to-first-token. Primary: median, p95.
/// 3. **Streaming throughput** — output tokens/s over a long generation. Primary: median tok/s.
/// 4. **TPOT** — time-per-output-token in the decode phase: (E2E − TTFT) / (outputTokens − 1).
actor BenchmarkSuite {
    private let client: AIClient
    private let model: AIModel
    private let providerName: String
    private let runs: Int

    /// Number of throwaway runs executed before measurement begins.
    /// Primes the Neural Engine, Core ML model cache, and Swift runtime.
    private static let warmupRuns = 3

    // Fixed prompts — kept constant across providers so results are comparable.
    private static let shortPrompt = "Reply with exactly one word: hello"
    private static let longPrompt  = "List the planets of the solar system, one per line, with a one-sentence fact about each."

    init(client: AIClient, model: AIModel, providerName: String, runs: Int = 10) {
        self.client       = client
        self.model        = model
        self.providerName = providerName
        self.runs         = runs
    }

    // MARK: - Entry point

    func run() async {
        printHeader()

        print("  Warming up (\(Self.warmupRuns) discarded runs)…")
        await warmup()
        print()

        let latency    = await measureNonStreamingLatency()
        let ttft       = await measureStreamingTTFT()
        let throughput = await measureStreamingThroughput()

        printResults(latency: latency, ttft: ttft, throughput: throughput)
    }

    // MARK: - Warm-up

    private func warmup() async {
        for i in 1...Self.warmupRuns {
            print("  [warm-up \(i)/\(Self.warmupRuns)] …", terminator: "\r")
            fflush(stdout)
            let request = try? AIRequestBuilder()
                .model(model)
                .addMessage(.user(text: Self.shortPrompt))
                .maxTokens(16)
                .build()
            if let req = request {
                _ = try? await client.send(req)
            }
        }
        clearLine()
    }

    // MARK: - Scenarios

    /// Non-streaming: measures the full round-trip until `client.send()` returns.
    private func measureNonStreamingLatency() async -> BenchmarkStats {
        var samples: [BenchmarkSample] = []

        for i in 1...runs {
            print("  [latency    \(i)/\(runs)] …", terminator: "\r")
            fflush(stdout)

            do {
                let request = try AIRequestBuilder()
                    .model(model)
                    .addMessage(.user(text: Self.shortPrompt))
                    .maxTokens(32)
                    .build()

                let start    = Date()
                let response = try await client.send(request)
                let elapsed  = Date().timeIntervalSince(start)

                let (outTokens, outEstimated) = outputTokens(response)
                samples.append(BenchmarkSample(
                    duration:        elapsed,
                    inputTokens:     response.usage.inputTokens,
                    outputTokens:    outTokens,
                    tokensEstimated: outEstimated
                ))
            } catch {
                print("  [latency \(i)/\(runs)] error: \(error)")
            }
        }

        clearLine()
        return BenchmarkStats(name: "Non-streaming latency", samples: samples)
    }

    /// Streaming TTFT + TPOT: time from request dispatch to the first `.textDelta`,
    /// and inter-token decode time derived from the full E2E duration.
    private func measureStreamingTTFT() async -> BenchmarkStats {
        var samples: [BenchmarkSample] = []

        for i in 1...runs {
            print("  [ttft       \(i)/\(runs)] …", terminator: "\r")
            fflush(stdout)

            do {
                let request = try AIRequestBuilder()
                    .model(model)
                    .addMessage(.user(text: Self.shortPrompt))
                    .maxTokens(64)
                    .build()

                let start              = Date()
                var ttft: TimeInterval?
                var finalResponse: AIResponse?

                for try await event in await client.stream(request) {
                    switch event {
                    case .textDelta:
                        if ttft == nil { ttft = Date().timeIntervalSince(start) }
                    case .message(let response):
                        finalResponse = response
                    default:
                        break
                    }
                }

                let elapsed = Date().timeIntervalSince(start)

                if let ttftValue = ttft, let resp = finalResponse {
                    let (outTokens, outEstimated) = outputTokens(resp)
                    samples.append(BenchmarkSample(
                        duration:        elapsed,
                        ttft:            ttftValue,
                        inputTokens:     resp.usage.inputTokens,
                        outputTokens:    outTokens,
                        tokensEstimated: outEstimated
                    ))
                }
            } catch {
                print("  [ttft \(i)/\(runs)] error: \(error)")
            }
        }

        clearLine()
        return BenchmarkStats(name: "Streaming TTFT", samples: samples)
    }

    /// Streaming throughput: output tokens per second over a longer completion.
    /// Duration is measured from the first delta (decode phase only, excludes prefill).
    private func measureStreamingThroughput() async -> BenchmarkStats {
        var samples: [BenchmarkSample] = []

        for i in 1...runs {
            print("  [throughput \(i)/\(runs)] …", terminator: "\r")
            fflush(stdout)

            do {
                let request = try AIRequestBuilder()
                    .model(model)
                    .addMessage(.user(text: Self.longPrompt))
                    .maxTokens(512)
                    .build()

                let requestStart       = Date()
                var decodeStart: Date?
                var finalResponse: AIResponse?

                for try await event in await client.stream(request) {
                    switch event {
                    case .textDelta:
                        if decodeStart == nil { decodeStart = Date() }
                    case .message(let response):
                        finalResponse = response
                    default:
                        break
                    }
                }

                // Use decode-phase duration (first token → last token) for tok/s.
                // Fall back to full request duration if TTFT was not captured.
                let decodeElapsed = decodeStart.map { Date().timeIntervalSince($0) }
                    ?? Date().timeIntervalSince(requestStart)
                let ttft = decodeStart.map { $0.timeIntervalSince(requestStart) }

                if let resp = finalResponse {
                    let (outTokens, outEstimated) = outputTokens(resp)
                    samples.append(BenchmarkSample(
                        duration:        decodeElapsed,
                        ttft:            ttft,
                        inputTokens:     resp.usage.inputTokens,
                        outputTokens:    outTokens,
                        tokensEstimated: outEstimated
                    ))
                }
            } catch {
                print("  [throughput \(i)/\(runs)] error: \(error)")
            }
        }

        clearLine()
        return BenchmarkStats(name: "Streaming throughput", samples: samples)
    }

    // MARK: - Token estimation

    /// Returns `(count, estimated)` — the output token count and whether it was
    /// derived from the char/4 heuristic rather than reported by the provider.
    private func outputTokens(_ response: AIResponse) -> (count: Int, estimated: Bool) {
        guard response.usage.outputTokens == 0 else {
            return (response.usage.outputTokens, false)
        }
        return (max(1, response.text.utf16.count / 4), true)
    }

    // MARK: - Output

    private func printHeader() {
        print("═══════════════════════════════════════════════════════════════")
        print("  AIProviderKit — Benchmark")
        print("  Provider : \(providerName)")
        print("  Model    : \(model.identifier)")
        print("  Runs     : \(runs) measured + \(Self.warmupRuns) warm-up (discarded)")
        print("═══════════════════════════════════════════════════════════════\n")
    }

    private func printResults(
        latency: BenchmarkStats,
        ttft: BenchmarkStats,
        throughput: BenchmarkStats
    ) {
        let c1 = 26, c2 = 9

        func pad(_ s: String, _ len: Int) -> String {
            s.padding(toLength: len, withPad: " ", startingAt: 0)
        }
        func fmt(_ v: Double, _ unit: String) -> String {
            String(format: "%.3f\(unit)", v)
        }

        print("  \(pad("Scenario", c1))  \(pad("Median", c2))  \(pad("Mean", c2))  \(pad("p95", c2))  \(pad("Min", c2))  Max")
        print("  " + String(repeating: "─", count: 76))

        func durationRow(_ stats: BenchmarkStats) {
            let row = [
                pad(stats.name, c1),
                pad(fmt(stats.medianDuration, " s"), c2),
                pad(fmt(stats.meanDuration, " s"), c2),
                pad(fmt(stats.p95Duration, " s"), c2),
                pad(fmt(stats.minDuration, " s"), c2),
                fmt(stats.maxDuration, " s")
            ].joined(separator: "  ")
            print("  \(row)")
        }

        durationRow(latency)

        // TTFT row — show TTFT median, not E2E duration
        let ttftRow = [
            pad(ttft.name, c1),
            pad(fmt(ttft.medianTTFT, " s"), c2),
            pad(fmt(ttft.meanTTFT, " s"), c2),
            pad(fmt(ttft.p95TTFT, " s"), c2),
            pad(fmt(ttft.minDuration, " s"), c2),
            fmt(ttft.maxDuration, " s")
        ].joined(separator: "  ")
        print("  \(ttftRow)")

        // TPOT row (derived from TTFT suite)
        if ttft.tpot > 0 {
            let tpotMs = ttft.tpot * 1_000
            print("  \(pad("TPOT (decode phase)", c1))  \(String(format: "%.1f ms/tok", tpotMs))")
        }

        // Throughput row
        let tps = String(format: "%.1f tok/s  (decode phase, median)", throughput.tokensPerSecond)
        print("  \(pad(throughput.name, c1))  \(tps)")

        print("\n  " + String(repeating: "─", count: 76))
        print("  Token usage — mean over latency scenario")
        let inputLabel  = latency.meanInputTokens == 0
            ? "not reported"
            : String(format: "%.0f", latency.meanInputTokens)
        let estimatedSuffix = latency.tokensEstimated ? " (estimated via char/4 heuristic)" : ""
        let outputLabel = String(format: "%.0f", latency.meanOutputTokens) + estimatedSuffix
        print("    Input:  \(inputLabel)")
        print("    Output: \(outputLabel)")
        print(String(format: "    Std dev (latency):  %.3f s", latency.stdDevDuration))
        print()
    }

    private func clearLine() {
        print(String(repeating: " ", count: 50), terminator: "\r")
        fflush(stdout)
    }
}
