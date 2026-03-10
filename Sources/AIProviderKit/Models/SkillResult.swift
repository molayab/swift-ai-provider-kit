/// The outcome of executing a `Skill`.
public struct SkillResult: Sendable {

    /// The primary output text produced by the skill.
    public let output: String

    /// Optional structured metadata from the skill's processing logic.
    public let metadata: [String: JSONValue]

    /// Token usage incurred during the skill's execution.
    public let usage: TokenUsage

    public init(
        output: String,
        metadata: [String: JSONValue] = [:],
        usage: TokenUsage
    ) {
        self.output = output
        self.metadata = metadata
        self.usage = usage
    }
}
