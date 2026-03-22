/// A composable, reusable AI capability backed by tools and an optional recipe.
///
/// Skills bundle a set of `Tool`s, an optional `Recipe`, and post-processing
/// logic into a single unit that `AIClient` can execute by identifier.
///
/// ```swift
/// struct SummarizationSkill: Skill {
///     let identifier = "summarize"
///     let description = "Summarizes any text"
///     let tools: [Tool] = []
///     let recipe: Recipe? = Recipe(id: "summarize", ...)
///
///     func process(response: AIResponse) async throws -> SkillResult {
///         SkillResult(output: response.text, usage: response.usage)
///     }
/// }
/// ```
public protocol Skill: Sendable {

    /// A unique, stable identifier used to look the skill up in `SkillRegistry`.
    var identifier: String { get }

    /// Human-readable description of what the skill does.
    var description: String { get }

    /// Tools made available to the model during skill execution.
    var tools: [Tool] { get }

    /// Optional prompt template applied when invoking this skill.
    var recipe: Recipe? { get }

    /// Post-processes the raw model response into a `SkillResult`.
    ///
    /// The default implementation passes `response.text` through unchanged with
    /// empty metadata. Override this to apply custom extraction or transformation.
    func process(response: AIResponse) async throws -> SkillResult
}

public extension Skill {
    func process(response: AIResponse) async throws -> SkillResult {
        SkillResult(output: response.text, metadata: [:], usage: response.usage)
    }
}
