import Foundation
import AIProviderKit
import ClaudeProvider
import OpenAIProvider
import AppleIntelligenceProvider

/// `runner` — AIProviderKit interactive chat CLI.
///
/// Usage:
///   runner chat      claude              # requires ANTHROPIC_API_KEY
///   runner chat      openai              # requires OPENAI_API_KEY
///   runner chat      apple-intelligence  # requires Apple Intelligence on-device
///
///   runner test      claude              # run Claude integration suite
///   runner test      openai              # run OpenAI integration suite
///   runner test      apple-intelligence  # run Apple Intelligence integration suite
///   runner test      all                 # run all available suites
///
///   runner benchmark claude              # benchmark Claude
///   runner benchmark openai              # benchmark OpenAI
///   runner benchmark apple-intelligence  # benchmark Apple Intelligence
///   runner benchmark all                 # benchmark all available providers
///   runner benchmark claude --runs 5     # override number of runs (default: 3)
@main
struct ChatApp {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        guard let command = args.first?.lowercased() else {
            printUsage(); exit(1)
        }

        switch command {
        case "chat":
            await runChat(args: Array(args.dropFirst()))
        case "test":
            await runTest(args: Array(args.dropFirst()))
        case "benchmark":
            await runBenchmark(args: Array(args.dropFirst()))
        default:
            printUsage(); exit(1)
        }
    }

    // MARK: - Chat

    private static func runChat(args: [String]) async {
        guard let provider = args.first?.lowercased() else {
            printChatUsage(); exit(1)
        }

        switch provider {
        case "claude":
            guard let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty else {
                print("error: ANTHROPIC_API_KEY not set"); exit(1)
            }
            let client = AIClient(
                provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: key))
            )
            await ChatSession(client: client, providerName: "Claude", defaultModel: .claudeHaiku45).run()

        case "openai":
            guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty else {
                print("error: OPENAI_API_KEY not set"); exit(1)
            }
            let client = AIClient(
                provider: OpenAIProvider(authorization: BearerAuthorization(apiKey: key))
            )
            await ChatSession(client: client, providerName: "OpenAI", defaultModel: .gpt41Mini).run()

        case "apple-intelligence":
            guard AppleIntelligenceAvailability.isAvailable else {
                print("error: Apple Intelligence is not available on this device"); exit(1)
            }
            let client = AIClient(provider: AppleIntelligenceProvider())
            await ChatSession(
                client: client,
                providerName: "Apple Intelligence",
                defaultModel: .appleIntelligenceDefault
            ).run()

        default:
            printChatUsage(); exit(1)
        }
    }

    // MARK: - Test

    private static func runTest(args: [String]) async {
        guard let suite = args.first?.lowercased() else {
            printTestUsage(); exit(1)
        }

        switch suite {
        case "claude":
            guard let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty else {
                print("error: ANTHROPIC_API_KEY not set"); exit(1)
            }
            await ClaudeIntegrationSuite(apiKey: key).runAll()

        case "openai":
            guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty else {
                print("error: OPENAI_API_KEY not set"); exit(1)
            }
            await OpenAIIntegrationSuite(apiKey: key).runAll()

        case "apple-intelligence":
            guard AppleIntelligenceAvailability.isAvailable else {
                print("error: Apple Intelligence is not available on this device"); exit(1)
            }
            await AppleIntelligenceIntegrationSuite().runAll()

        case "all":
            await runAllTests()

        default:
            printTestUsage(); exit(1)
        }
    }

    private static func runAllTests() async {
        var ran = false

        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
            ran = true
            await ClaudeIntegrationSuite(apiKey: key).runAll()
        } else {
            print("info: ANTHROPIC_API_KEY not set — skipping Claude suite")
        }

        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            ran = true
            await OpenAIIntegrationSuite(apiKey: key).runAll()
        } else {
            print("info: OPENAI_API_KEY not set — skipping OpenAI suite")
        }

        if AppleIntelligenceAvailability.isAvailable {
            ran = true
            await AppleIntelligenceIntegrationSuite().runAll()
        } else {
            print("info: Apple Intelligence not available — skipping on-device suite")
        }

        if !ran {
            print("error: no suites ran — set ANTHROPIC_API_KEY, OPENAI_API_KEY, or run on an Apple Intelligence device")
            exit(1)
        }
    }

    // MARK: - Benchmark

    private static func runBenchmark(args: [String]) async {
        guard let provider = args.first?.lowercased() else {
            printBenchmarkUsage(); exit(1)
        }

        let runs = parseRuns(from: args)

        switch provider {
        case "claude":
            guard let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty else {
                print("error: ANTHROPIC_API_KEY not set"); exit(1)
            }
            let client = AIClient(
                provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: key))
            )
            await BenchmarkSuite(client: client, model: .claudeHaiku45, providerName: "Claude", runs: runs).run()

        case "openai":
            guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty else {
                print("error: OPENAI_API_KEY not set"); exit(1)
            }
            let client = AIClient(
                provider: OpenAIProvider(authorization: BearerAuthorization(apiKey: key))
            )
            await BenchmarkSuite(client: client, model: .gpt41Mini, providerName: "OpenAI", runs: runs).run()

        case "apple-intelligence":
            guard AppleIntelligenceAvailability.isAvailable else {
                print("error: Apple Intelligence is not available on this device"); exit(1)
            }
            let client = AIClient(provider: AppleIntelligenceProvider())
            await BenchmarkSuite(
                client: client,
                model: .appleIntelligenceDefault,
                providerName: "Apple Intelligence",
                runs: runs
            ).run()

        case "all":
            await runAllBenchmarks(runs: runs)

        default:
            printBenchmarkUsage(); exit(1)
        }
    }

    private static func runAllBenchmarks(runs: Int) async {
        var ran = false

        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
            ran = true
            let client = AIClient(
                provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: key))
            )
            await BenchmarkSuite(client: client, model: .claudeHaiku45, providerName: "Claude", runs: runs).run()
        } else {
            print("info: ANTHROPIC_API_KEY not set — skipping Claude")
        }

        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            ran = true
            let client = AIClient(
                provider: OpenAIProvider(authorization: BearerAuthorization(apiKey: key))
            )
            await BenchmarkSuite(client: client, model: .gpt41Mini, providerName: "OpenAI", runs: runs).run()
        } else {
            print("info: OPENAI_API_KEY not set — skipping OpenAI")
        }

        if AppleIntelligenceAvailability.isAvailable {
            ran = true
            let client = AIClient(provider: AppleIntelligenceProvider())
            await BenchmarkSuite(
                client: client,
                model: .appleIntelligenceDefault,
                providerName: "Apple Intelligence",
                runs: runs
            ).run()
        } else {
            print("info: Apple Intelligence not available — skipping on-device benchmark")
        }

        if !ran {
            print("error: no benchmarks ran — set ANTHROPIC_API_KEY, OPENAI_API_KEY, or run on an Apple Intelligence device")
            exit(1)
        }
    }

    /// Parses `--runs <n>` from the argument list, defaulting to 3.
    private static func parseRuns(from args: [String]) -> Int {
        guard let idx = args.firstIndex(of: "--runs"), args.indices.contains(idx + 1),
              let n = Int(args[idx + 1]), n > 0 else { return 3 }
        return n
    }

    // MARK: - Help

    private static func printUsage() {
        print("""
        runner — AIProviderKit CLI

        Usage: runner <command> <provider> [options]

        Commands:
          chat       Start an interactive chat session with a provider
          test       Run live integration tests against a provider
          benchmark  Measure latency and throughput of a provider

        Run 'runner <command>' without a provider for options.
        """)
    }

    private static func printChatUsage() {
        print("""
        Usage: runner chat <provider>

        Providers:
          claude              Requires ANTHROPIC_API_KEY
          openai              Requires OPENAI_API_KEY
          apple-intelligence  Requires Apple Intelligence on-device
        """)
    }

    private static func printTestUsage() {
        print("""
        Usage: runner test <provider>

        Providers:
          claude              Requires ANTHROPIC_API_KEY
          openai              Requires OPENAI_API_KEY
          apple-intelligence  Requires Apple Intelligence on-device
          all                 Run all available suites
        """)
    }

    private static func printBenchmarkUsage() {
        print("""
        Usage: runner benchmark <provider> [--runs <n>]

        Providers:
          claude              Requires ANTHROPIC_API_KEY
          openai              Requires OPENAI_API_KEY
          apple-intelligence  Requires Apple Intelligence on-device
          all                 Benchmark all available providers

        Options:
          --runs <n>          Number of repetitions per scenario (default: 3)

        Scenarios measured:
          Non-streaming latency   Full round-trip time for a short completion
          Streaming TTFT          Time to first text delta
          Streaming throughput    Output tokens per second over a longer completion
        """)
    }
}
