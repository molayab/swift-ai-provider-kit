@testable import AIProviderKit
import Testing

@Suite("SkillRegistry")
struct SkillRegistryTests {

    // MARK: - Register and Retrieve

    @Test("register then skill(id:) returns correct skill")
    func register_thenSkillId_returnsCorrectSkill() async throws {
        // Given
        let registry = SkillRegistry()
        let skill = MockSkill(identifier: "summarize")

        // When
        await registry.register(skill)
        let retrieved = try await registry.skill(id: "summarize")

        // Then
        #expect(retrieved.identifier == "summarize")
    }

    @Test("skill(id:) throws skillNotFound for unknown id")
    func skillId_unknownId_throwsSkillNotFound() async {
        // Given
        let registry = SkillRegistry()

        // When / Then
        await #expect(throws: AIError.self) {
            try await registry.skill(id: "nonexistent")
        }
    }

    // MARK: - Unregister

    @Test("unregister removes a previously registered skill")
    func unregister_removesRegisteredSkill() async {
        // Given
        let registry = SkillRegistry()
        await registry.register(MockSkill(identifier: "removeme"))

        // When
        await registry.unregister(id: "removeme")

        // Then
        await #expect(throws: AIError.self) {
            try await registry.skill(id: "removeme")
        }
    }

    @Test("unregister on non-existent id does not throw")
    func unregister_nonExistentId_doesNotThrow() async {
        // Given
        let registry = SkillRegistry()

        // When / Then (should not throw)
        await registry.unregister(id: "ghost")
    }

    // MARK: - allSkills

    @Test("allSkills returns all registered skills")
    func allSkills_returnsAllRegistered() async {
        // Given
        let registry = SkillRegistry()
        await registry.register(MockSkill(identifier: "a"))
        await registry.register(MockSkill(identifier: "b"))

        // When
        let all = await registry.allSkills

        // Then
        #expect(all.count == 2)
        let ids = Set(all.map(\.identifier))
        #expect(ids.contains("a"))
        #expect(ids.contains("b"))
    }

    @Test("allSkills returns empty array when no skills registered")
    func allSkills_noSkills_returnsEmpty() async {
        // Given
        let registry = SkillRegistry()

        // When
        let all = await registry.allSkills

        // Then
        #expect(all.isEmpty)
    }

    // MARK: - Re-registration

    @Test("registering a skill with the same id replaces the previous one")
    func register_sameId_replacesPrevious() async throws {
        // Given
        let registry = SkillRegistry()
        let original = MockSkill(identifier: "skill", description: "Original")
        let replacement = MockSkill(identifier: "skill", description: "Replacement")

        // When
        await registry.register(original)
        await registry.register(replacement)
        let retrieved = try await registry.skill(id: "skill")

        // Then
        #expect(retrieved.description == "Replacement")
    }
}
