import Foundation

/// Shared test-runner logic for all integration suites.
///
/// Each integration suite composes an `IntegrationSuiteRunner` to record
/// pass/fail counts and print results, eliminating the boilerplate that would
/// otherwise be duplicated across `ClaudeIntegrationSuite`,
/// `OpenAIIntegrationSuite`, and `AppleIntelligenceIntegrationSuite`.
actor IntegrationSuiteRunner {
    private var passed = 0
    private var failed = 0

    /// Runs `body`, prints a pass/fail line, and updates the counters.
    func run(_ name: String, _ body: @Sendable () async throws -> Void) async {
        do {
            try await body()
            print("  ✅  \(name)")
            passed += 1
        } catch {
            print("  ❌  \(name)")
            print("       → \(error)")
            failed += 1
        }
    }

    /// Prints the suite summary and exits with code 1 if any test failed.
    func printSummary() {
        print("\n───────────────────────────────────────────")
        print("  \(passed + failed) tests — \(passed) passed, \(failed) failed")
        print("───────────────────────────────────────────")
        if failed > 0 { exit(1) }
    }
}
