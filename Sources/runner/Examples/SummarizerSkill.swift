import AIProviderKit

/// Simple skill fixture used by the skill integration test.
struct SummarizerSkill: Skill {
    let identifier  = "summarizer"
    let description = "Summarizes any text into a single concise sentence."
    let tools: [Tool] = []

    var recipe: Recipe? {
        Recipe(
            id: "summarizer-recipe",
            name: "Summarizer",
            description: "One-sentence summarizer",
            systemPrompt: "You are a concise summarizer. Reply with a single sentence that captures the key idea.",
            userPromptTemplate: "Summarize the following."
        )
    }

}
