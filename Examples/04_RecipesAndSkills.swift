/// Example: Recipes (prompt templates) and Skills (composable capabilities)
///
/// Demonstrates:
///   - Registering and rendering a `Recipe`
///   - Implementing and executing a `Skill`

import AIProviderKit
import ClaudeProvider

// MARK: - Recipe

let summarizerRecipe = Recipe(
    id: "com.example.summarize",
    name: "Summarizer",
    description: "Summarizes text in a specified style.",
    systemPrompt: "You are a concise, precise summarizer. Return only the summary.",
    userPromptTemplate: "Summarize the following in {{style}} style:\n\n{{text}}"
)

func useRecipe(client: AIClient) async throws {
    await client.recipeRegistry.register(summarizerRecipe)

    let response = try await client.send(
        recipe: summarizerRecipe,
        values: [
            "style": "three bullet points",
            "text": "Swift is a general-purpose programming language built using a modern approach..."
        ],
        model: .claudeSonnet46
    )
    print(response.text)
}

// MARK: - Skill

struct SummarizationSkill: Skill {
    let identifier  = "com.example.skill.summarize"
    let description = "Summarizes any text into bullet points."
    let tools: [Tool] = []
    let recipe: Recipe? = Recipe(
        id: "com.example.skill.summarize.recipe",
        name: "Summarizer",
        systemPrompt: "You are a precise summarizer.",
        userPromptTemplate: "Summarize in bullet points:\n\n{{input}}"
    )

    func process(response: AIResponse) async throws -> SkillResult {
        SkillResult(
            output: response.text,
            metadata: ["wordCount": .integer(response.text.split(separator: " ").count)],
            usage: response.usage
        )
    }
}

func useSkill(client: AIClient) async throws {
    await client.skillRegistry.register(SummarizationSkill())

    let result = try await client.execute(
        skillId: "com.example.skill.summarize",
        input: "Swift is a safe, fast, and expressive language...",
        model: .claudeSonnet46
    )

    print(result.output)
    print("Word count: \(result.metadata["wordCount"]?.intValue ?? 0)")
    print("Tokens used: \(result.usage.totalTokens)")
}
