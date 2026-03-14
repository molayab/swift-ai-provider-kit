import AIProviderKit

struct MockSkill: Skill {

    let identifier: String
    let description: String
    let tools: [Tool]
    let recipe: Recipe?

    var stubbedResult: SkillResult
    var processCallCount = 0

    init(
        identifier: String = "mock-skill",
        description: String = "A mock skill for testing",
        tools: [Tool] = [],
        recipe: Recipe? = nil,
        stubbedResult: SkillResult = SkillResult(
            output: "mock output",
            usage: TokenUsage(inputTokens: 5, outputTokens: 3)
        )
    ) {
        self.identifier = identifier
        self.description = description
        self.tools = tools
        self.recipe = recipe
        self.stubbedResult = stubbedResult
    }

    // swiftlint:disable:next async_without_await unneeded_throws_rethrows
    func process(response: AIResponse) async throws -> SkillResult {
        stubbedResult
    }
}
