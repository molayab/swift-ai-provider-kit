import Foundation

/// Entry point for the integration test runner.
///
/// Requires the `ANTHROPIC_API_KEY` environment variable to be set.
/// Run with:
///   ANTHROPIC_API_KEY=sk-... swift run IntegrationTests
@main
struct IntegrationApp {
    static func main() async {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
              !apiKey.isEmpty else {
            print("⚠️  ANTHROPIC_API_KEY not set — skipping integration tests")
            return
        }

        await ClaudeIntegrationSuite(apiKey: apiKey).runAll()
    }
}
