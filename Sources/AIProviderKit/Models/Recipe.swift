import Foundation

/// A reusable prompt template with named `{{placeholder}}` substitutions.
///
/// Recipes decouple prompt engineering from code. Register them in
/// `RecipeRegistry` and render on demand with caller-supplied values.
///
/// ```swift
/// let recipe = Recipe(
///     id: "summarize",
///     name: "Summarizer",
///     systemPrompt: "You are a concise summarizer.",
///     userPromptTemplate: "Summarize in {{style}} style:\n\n{{text}}"
/// )
/// let rendered = try recipe.render(with: ["style": "bullet points", "text": article])
/// ```
public struct Recipe: Sendable, Identifiable {

    public let id: String
    public let name: String
    public let description: String
    public let systemPrompt: String?

    /// The template string. Use `{{key}}` for substitutable placeholders.
    public let userPromptTemplate: String

    public init(
        id: String,
        name: String,
        description: String = "",
        systemPrompt: String? = nil,
        userPromptTemplate: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
        self.userPromptTemplate = userPromptTemplate
    }

    /// Renders the template by substituting all `{{key}}` placeholders.
    ///
    /// - Throws: `AIError.recipeRenderingFailed` if any placeholder is unresolved.
    public func render(with values: [String: String] = [:]) throws -> RenderedRecipe {
        var prompt = userPromptTemplate
        for (key, value) in values {
            prompt = prompt.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        let missingKeys = extractPlaceholders(from: prompt)
        guard missingKeys.isEmpty else {
            throw AIError.recipeRenderingFailed(recipeId: id, missingKeys: missingKeys)
        }

        return RenderedRecipe(systemPrompt: systemPrompt, userPrompt: prompt)
    }

    private func extractPlaceholders(from string: String) -> [String] {
        var keys: [String] = []
        var remaining = string
        while let open = remaining.range(of: "{{"),
              let close = remaining[open.upperBound...].range(of: "}}") {
            keys.append(String(remaining[open.upperBound..<close.lowerBound]))
            remaining = String(remaining[close.upperBound...])
        }
        return keys
    }
}

// MARK: -

/// The result of rendering a `Recipe` with concrete values.
public struct RenderedRecipe: Sendable {
    public let systemPrompt: String?
    public let userPrompt: String
}
