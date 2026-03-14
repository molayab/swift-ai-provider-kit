import AIProviderKit
import Testing

@Suite("Recipe")
struct RecipeTests {

    let recipe = Recipe(
        id: "test.summarize",
        name: "Summarizer",
        systemPrompt: "You are a concise summarizer.",
        userPromptTemplate: "Summarize in {{style}} style:\n\n{{text}}"
    )

    @Test("render substitutes all placeholders")
    func renderSubstitutesPlaceholders() throws {
        // GIVEN
        let values = ["style": "bullet points", "text": "Long article here."]

        // WHEN
        let rendered = try recipe.render(with: values)

        // THEN
        #expect(rendered.userPrompt == "Summarize in bullet points style:\n\nLong article here.")
        #expect(rendered.systemPrompt == "You are a concise summarizer.")
    }

    @Test("render throws when a placeholder is unresolved")
    func renderThrowsOnMissingKey() {
        // GIVEN
        let values = ["style": "bullet points"] // missing "text"

        // WHEN / THEN
        #expect(throws: AIError.self) {
            try recipe.render(with: values)
        }
    }

    @Test("render with empty values throws when template has placeholders")
    func renderThrowsWithNoValues() {
        // GIVEN / WHEN / THEN
        #expect(throws: AIError.self) {
            try recipe.render()
        }
    }

    @Test("render succeeds for templates with no placeholders")
    func renderSucceedsWithNoPlaceholders() throws {
        // GIVEN
        let staticRecipe = Recipe(
            id: "static",
            name: "Static",
            userPromptTemplate: "Hello world"
        )

        // WHEN
        let rendered = try staticRecipe.render()

        // THEN
        #expect(rendered.userPrompt == "Hello world")
    }
}
