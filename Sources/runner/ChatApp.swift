import AIProviderKit
import AppleIntelligenceProvider
import ClaudeProvider
import Foundation
import OpenAIProvider

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
///   runner benchmark apple-intelligence  # benchmark Apple Intelligence (local only)
///   runner benchmark apple-intelligence --runs 5  # override number of runs (default: 10)
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

    // MARK: - Helpers

    /// Reads an environment variable and exits with an error message if it is absent or empty.
    private static func requireEnv(_ key: String) -> String {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
            print("error: \(key) not set"); exit(1)
        }
        return value
    }

    // MARK: - Chat

    private static func runChat(args: [String]) async {
        guard let provider = args.first?.lowercased() else {
            printChatUsage(); exit(1)
        }

        switch provider {
        case "claude":
            let key = requireEnv("ANTHROPIC_API_KEY")
            let client = AIClient(
                provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: key))
            )
            await ChatSession(client: client, providerName: "Claude", defaultModel: ClaudeModel.haiku45.aiModel).run()

        case "openai":
            let key = requireEnv("OPENAI_API_KEY")
            let client = AIClient(
                provider: OpenAIProvider(authorization: BearerAuthorization(apiKey: key))
            )
            await ChatSession(client: client, providerName: "OpenAI", defaultModel: OpenAIModel.gpt41Mini.aiModel).run()

        case "apple-intelligence":
            guard AppleIntelligenceAvailability.isAvailable else {
                print("error: Apple Intelligence is not available on this device"); exit(1)
            }
            let client = AIClient(provider: AppleIntelligenceProvider())
            await ChatSession(
                client: client,
                providerName: "Apple Intelligence",
                defaultModel: AppleIntelligenceModel.default.aiModel
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
            await ClaudeIntegrationSuite(apiKey: requireEnv("ANTHROPIC_API_KEY")).runAll()

        case "openai":
            await OpenAIIntegrationSuite(apiKey: requireEnv("OPENAI_API_KEY")).runAll()

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
        case "apple-intelligence":
            guard AppleIntelligenceAvailability.isAvailable else {
                print("error: Apple Intelligence is not available on this device"); exit(1)
            }
            let client = AIClient(provider: AppleIntelligenceProvider())
            await BenchmarkSuite(
                client: client,
                model: AppleIntelligenceModel.default.aiModel,
                providerName: "Apple Intelligence",
                runs: runs
            ).run()

        default:
            printBenchmarkUsage(); exit(1)
        }
    }

    /// Parses `--runs <n>` from the argument list, defaulting to 10.
    private static func parseRuns(from args: [String]) -> Int {
        guard let idx = args.firstIndex(of: "--runs"), args.indices.contains(idx + 1),
              let count = Int(args[idx + 1]), count > 0 else { return 10 }
        return count
    }

    // MARK: - Help

    private static func printUsage() {
        print("""
        runner — AIProviderKit CLI

        Usage: runner <command> <provider> [options]

        Commands:
          chat       Start an interactive chat session with a provider
          test       Run live integration tests against a provider
          benchmark  Measure latency and throughput (local providers only)

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
        Usage: runner benchmark apple-intelligence [--runs <n>]

        Benchmarks are only available for local (on-device) providers.
        Cloud providers (Claude, OpenAI) are excluded — network latency and
        server load make results non-reproducible and provider-specific.

        Providers:
          apple-intelligence  Requires Apple Intelligence on-device

        Options:
          --runs <n>          Number of measured repetitions per scenario (default: 10)
                              3 additional warm-up runs are always discarded first.

        Scenarios measured:
          Non-streaming latency   Full round-trip time for a short completion
          Streaming TTFT          Time to first text delta (median, p95)
          TPOT                    Time per output token in the decode phase
          Streaming throughput    Output tokens/s over a longer completion
        """)
    }
}
