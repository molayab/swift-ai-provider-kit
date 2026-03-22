/// Thread-safe registry for `Recipe` instances.
public actor RecipeRegistry {

    private var recipes: [String: Recipe] = [:]

    public init() {}

    /// Registers a recipe, keyed by ``Recipe/id``. Replaces any existing recipe with the same identifier.
    public func register(_ recipe: Recipe) {
        recipes[recipe.id] = recipe
    }

    /// Removes the recipe with the given identifier. No-op if the identifier is not registered.
    public func unregister(id: String) {
        recipes.removeValue(forKey: id)
    }

    /// Returns the recipe registered under `id`.
    /// - Throws: ``AIError/recipeNotFound(_:)`` if no recipe is registered with that identifier.
    public func recipe(id: String) throws(AIError) -> Recipe {
        guard let recipe = recipes[id] else {
            throw AIError.recipeNotFound(id)
        }
        return recipe
    }

    /// All currently registered recipes, in unspecified order.
    public var allRecipes: [Recipe] {
        Array(recipes.values)
    }
}
