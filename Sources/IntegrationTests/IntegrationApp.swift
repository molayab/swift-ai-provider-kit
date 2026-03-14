import Foundation
import AppleIntelligenceProvider

/// Entry point for the integration test runner.
///
/// Usage:
///   ANTHROPIC_API_KEY=sk-... swift package integration-tests claude
///   swift package integration-tests apple-intelligence
///   ANTHROPIC_API_KEY=sk-... swift package integration-tests all
@main
struct IntegrationApp {
    static func main() async {
        switch CommandLine.arguments.dropFirst().first?.lowercased() {
        case "claude":
            await runClaude()
        case "apple-intelligence":
            await runAppleIntelligence()
        case "all":
            await runAll()
        default:
            printUsage()
            exit(1)
        }
    }

    // MARK: - Suites

    private static func runClaude() async {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty else {
            print("⚠️  ANTHROPIC_API_KEY not set")
            exit(1)
        }
        await ClaudeIntegrationSuite(apiKey: apiKey).runAll()
    }

    private static func runAppleIntelligence() async {
        guard AppleIntelligenceAvailability.isAvailable else {
            print("⚠️  Apple Intelligence is not available on this device")
            exit(1)
        }
        await AppleIntelligenceIntegrationSuite().runAll()
    }

    private static func runAll() async {
        var ranAnySuite = false

        if let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty {
            ranAnySuite = true
            await ClaudeIntegrationSuite(apiKey: apiKey).runAll()
        } else {
            print("ℹ️  ANTHROPIC_API_KEY not set — skipping Claude suite")
        }

        if AppleIntelligenceAvailability.isAvailable {
            ranAnySuite = true
            await AppleIntelligenceIntegrationSuite().runAll()
        } else {
            print("ℹ️  Apple Intelligence not available — skipping on-device suite")
        }

        if !ranAnySuite {
            print("⚠️  No suites ran. Set ANTHROPIC_API_KEY or run on an Apple Intelligence enabled device.")
            exit(1)
        }
    }

    // MARK: - Help

    private static func printUsage() {
        print("""
        Usage: swift package integration-tests <provider>

        Providers:
          claude              Claude (Anthropic) suite — requires ANTHROPIC_API_KEY
          apple-intelligence  On-device Apple Intelligence suite — requires Apple Intelligence enabled
          all                 Run all available suites
        """)
    }
}
