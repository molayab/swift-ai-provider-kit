/// Thread-safe registry for `Recipe` instances.
public actor RecipeRegistry {

    private var recipes: [String: Recipe] = [:]

    public init() {}

    public func register(_ recipe: Recipe) {
        recipes[recipe.id] = recipe
    }

    public func unregister(id: String) {
        recipes.removeValue(forKey: id)
    }

    public func recipe(id: String) throws(AIError) -> Recipe {
        guard let recipe = recipes[id] else {
            throw AIError.recipeNotFound(id)
        }
        return recipe
    }

    public var allRecipes: [Recipe] {
        Array(recipes.values)
    }
}
