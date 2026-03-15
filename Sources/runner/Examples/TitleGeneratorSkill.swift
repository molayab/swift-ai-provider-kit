import AIProviderKit

/// Example skill: generates a short, punchy title for any text the user provides.
///
/// Invoke from the chat REPL with:
///   /skill title <text>
struct TitleGeneratorSkill: Skill {
    let identifier  = "title-generator"
    let description = "Generates a concise, compelling title for any text."
    let tools: [Tool] = []

    var recipe: Recipe? {
        Recipe(
            id: "title-generator-recipe",
            name: "Title Generator",
            description: "Generates a short title for the provided text.",
            systemPrompt: """
            You are a professional copywriter. Reply with a single short title \
            (5 words or fewer). No punctuation at the end.
            """,
            userPromptTemplate: "Generate a concise title for the text the user provided."
        )
    }

    func process(response: AIResponse) async throws -> SkillResult {
        SkillResult(output: response.text, metadata: [:], usage: response.usage)
    }
}
