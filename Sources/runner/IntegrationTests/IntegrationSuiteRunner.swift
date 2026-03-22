import AIProviderKit
import AIProviderTools
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

    /// Prints the standard suite header with the given provider name.
    func printHeader(provider: String) {
        print("═══════════════════════════════════════════")
        print("  AIProviderKit — Integration Tests")
        print("  Provider : \(provider)")
        print("═══════════════════════════════════════════\n")
    }

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

    /// Runs the standard recipe test using the translate recipe.
    func runRecipeTest(client: AIClient, model: AIModel) async {
        await run("Recipe rendering") {
            let recipe = Recipe(
                id: "translate",
                name: "Translate",
                description: "Translates a word or phrase to a target language.",
                systemPrompt: "You are a concise translator. Reply with only the translation, no extra text.",
                userPromptTemplate: "Translate '{{text}}' to {{language}}."
            )
            let response = try await client.send(
                recipe: recipe,
                values: ["text": "hello", "language": "Spanish"],
                model: model
            )
            guard !response.text.isEmpty else { throw IntegrationError.emptyResponse }
        }
    }

    /// Runs the standard skill test using `SummarizerSkill`.
    func runSkillTest(client: AIClient, model: AIModel) async {
        await run("Skill execution") {
            let skill = SummarizerSkill()
            await client.skillRegistry.register(skill)
            let result = try await client.execute(
                skillId: skill.identifier,
                input: "The quick brown fox jumps over the lazy dog. This classic pangram uses every letter of the alphabet.",
                model: model
            )
            guard !result.output.isEmpty else { throw IntegrationError.emptyResponse }
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
