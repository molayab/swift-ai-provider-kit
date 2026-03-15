import Foundation
import AIProviderKit

/// Runs a set of latency and throughput benchmarks against any `AIClient`.
///
/// Three scenarios are measured across `runs` repetitions each:
/// 1. **Non-streaming latency** — round-trip time for a short completion.
/// 2. **Streaming TTFT** — time from request send to the first text delta.
/// 3. **Streaming throughput** — output tokens per second over a long completion.
actor BenchmarkSuite {
    private let client: AIClient
    private let model: AIModel
    private let providerName: String
    private let runs: Int

    // Fixed prompts — kept short/deterministic to make results comparable.
    private static let shortPrompt = "Reply with exactly one word: hello"
    private static let longPrompt  = "List the planets of the solar system, one per line, with a one-sentence fact about each."

    init(client: AIClient, model: AIModel, providerName: String, runs: Int = 3) {
        self.client       = client
        self.model        = model
        self.providerName = providerName
        self.runs         = runs
    }

    // MARK: - Entry point

    func run() async {
        printHeader()

        let latency    = await measureNonStreamingLatency()
        let ttft       = await measureStreamingTTFT()
        let throughput = await measureStreamingThroughput()

        printResults(latency: latency, ttft: ttft, throughput: throughput)
    }

    // MARK: - Scenarios

    /// Non-streaming: measures the full round-trip until `client.send()` returns.
    private func measureNonStreamingLatency() async -> BenchmarkStats {
        var samples: [BenchmarkSample] = []

        for i in 1...runs {
            print("  [latency   \(i)/\(runs)] ...", terminator: "\r")
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

                samples.append(BenchmarkSample(
                    duration:     elapsed,
                    inputTokens:  response.usage.inputTokens,
                    outputTokens: response.usage.outputTokens
                ))
            } catch {
                print("  [latency \(i)/\(runs)] error: \(error)")
            }
        }

        clearLine()
        return BenchmarkStats(name: "Non-streaming latency", samples: samples)
    }

    /// Streaming TTFT: time from request dispatch to the first `.textDelta` event.
    private func measureStreamingTTFT() async -> BenchmarkStats {
        var samples: [BenchmarkSample] = []

        for i in 1...runs {
            print("  [ttft      \(i)/\(runs)] ...", terminator: "\r")
            fflush(stdout)

            do {
                let request = try AIRequestBuilder()
                    .model(model)
                    .addMessage(.user(text: Self.shortPrompt))
                    .maxTokens(32)
                    .build()

                let start         = Date()
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

                if let ttft, let resp = finalResponse {
                    samples.append(BenchmarkSample(
                        duration:     ttft,
                        inputTokens:  resp.usage.inputTokens,
                        outputTokens: resp.usage.outputTokens
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
    private func measureStreamingThroughput() async -> BenchmarkStats {
        var samples: [BenchmarkSample] = []

        for i in 1...runs {
            print("  [throughput \(i)/\(runs)] ...", terminator: "\r")
            fflush(stdout)

            do {
                let request = try AIRequestBuilder()
                    .model(model)
                    .addMessage(.user(text: Self.longPrompt))
                    .maxTokens(512)
                    .build()

                let start         = Date()
                var finalResponse: AIResponse?

                for try await event in await client.stream(request) {
                    if case .message(let response) = event {
                        finalResponse = response
                    }
                }

                let elapsed = Date().timeIntervalSince(start)

                if let resp = finalResponse {
                    samples.append(BenchmarkSample(
                        duration:     elapsed,
                        inputTokens:  resp.usage.inputTokens,
                        outputTokens: resp.usage.outputTokens
                    ))
                }
            } catch {
                print("  [throughput \(i)/\(runs)] error: \(error)")
            }
        }

        clearLine()
        return BenchmarkStats(name: "Streaming throughput", samples: samples)
    }

    // MARK: - Output

    private func printHeader() {
        print("═══════════════════════════════════════════════════════")
        print("  AIProviderKit — Benchmark")
        print("  Provider : \(providerName)")
        print("  Model    : \(model.identifier)")
        print("  Runs     : \(runs) per scenario")
        print("═══════════════════════════════════════════════════════\n")
    }

    private func printResults(
        latency: BenchmarkStats,
        ttft: BenchmarkStats,
        throughput: BenchmarkStats
    ) {
        let col = 26
        func pad(_ s: String) -> String { s.padding(toLength: col, withPad: " ", startingAt: 0) }

        print("  \(pad("Scenario"))  \(pad("Mean"))   Min      Max")
        print("  " + String(repeating: "─", count: 66))

        func row(_ stats: BenchmarkStats, unit: String, value: (BenchmarkStats) -> Double) {
            let mean = String(format: "%.3f\(unit)", value(stats))
            let min  = String(format: "%.3f\(unit)", stats.minDuration)
            let max  = String(format: "%.3f\(unit)", stats.maxDuration)
            print("  \(pad(stats.name))  \(pad(mean))  \(min)   \(max)")
        }

        row(latency,    unit: " s",    value: \.meanDuration)
        row(ttft,       unit: " s",    value: \.meanDuration)

        let tps = String(format: "%.1f tok/s", throughput.tokensPerSecond)
        print("  \(pad(throughput.name))  \(pad(tps))  (output tokens / stream duration)")

        print("\n  " + String(repeating: "─", count: 66))
        print("  Token usage (mean, latency scenario)")
        print(String(format: "    Input:  %.0f tokens", latency.meanInputTokens))
        print(String(format: "    Output: %.0f tokens", latency.meanOutputTokens))
        print()
    }

    private func clearLine() {
        print(String(repeating: " ", count: 40), terminator: "\r")
        fflush(stdout)
    }
}
