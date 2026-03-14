@testable import AIProviderKit
import Testing

@Suite("RecipeRegistry")
struct RecipeRegistryTests {

    private func makeRecipe(id: String = "test-recipe") -> Recipe {
        Recipe(
            id: id,
            name: "Test Recipe",
            description: "A recipe for testing",
            userPromptTemplate: "Hello {{name}}"
        )
    }

    // MARK: - Register and Retrieve

    @Test("register then recipe(id:) returns correct recipe")
    func register_thenRecipeId_returnsCorrectRecipe() async throws {
        // Given
        let registry = RecipeRegistry()
        let recipe = makeRecipe(id: "summarize")

        // When
        await registry.register(recipe)
        let retrieved = try await registry.recipe(id: "summarize")

        // Then
        #expect(retrieved.id == "summarize")
        #expect(retrieved.name == "Test Recipe")
    }

    @Test("recipe(id:) throws recipeNotFound for unknown id")
    func recipeId_unknownId_throwsRecipeNotFound() async {
        // Given
        let registry = RecipeRegistry()

        // When / Then
        await #expect(throws: AIError.self) {
            try await registry.recipe(id: "nonexistent")
        }
    }

    // MARK: - Unregister

    @Test("unregister removes a previously registered recipe")
    func unregister_removesRegisteredRecipe() async {
        // Given
        let registry = RecipeRegistry()
        await registry.register(makeRecipe(id: "removeme"))

        // When
        await registry.unregister(id: "removeme")

        // Then
        await #expect(throws: AIError.self) {
            try await registry.recipe(id: "removeme")
        }
    }

    @Test("unregister on non-existent id does not throw")
    func unregister_nonExistentId_doesNotThrow() async {
        // Given
        let registry = RecipeRegistry()

        // When / Then (should not throw)
        await registry.unregister(id: "ghost")
    }

    // MARK: - allRecipes

    @Test("allRecipes returns all registered recipes")
    func allRecipes_returnsAllRegistered() async {
        // Given
        let registry = RecipeRegistry()
        await registry.register(makeRecipe(id: "alpha"))
        await registry.register(makeRecipe(id: "beta"))

        // When
        let all = await registry.allRecipes

        // Then
        #expect(all.count == 2)
        let ids = Set(all.map(\.id))
        #expect(ids.contains("alpha"))
        #expect(ids.contains("beta"))
    }

    @Test("allRecipes returns empty array when no recipes registered")
    func allRecipes_noRecipes_returnsEmpty() async {
        // Given
        let registry = RecipeRegistry()

        // When
        let all = await registry.allRecipes

        // Then
        #expect(all.isEmpty)
    }

    // MARK: - Re-registration

    @Test("registering a recipe with the same id replaces the previous one")
    func register_sameId_replacesPrevious() async throws {
        // Given
        let registry = RecipeRegistry()
        let original = Recipe(id: "r1", name: "Original", userPromptTemplate: "A")
        let replacement = Recipe(id: "r1", name: "Replacement", userPromptTemplate: "B")

        // When
        await registry.register(original)
        await registry.register(replacement)
        let retrieved = try await registry.recipe(id: "r1")

        // Then
        #expect(retrieved.name == "Replacement")
    }
}
