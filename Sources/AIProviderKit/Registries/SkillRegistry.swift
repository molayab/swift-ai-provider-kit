/// Thread-safe registry for `Skill` instances.
public actor SkillRegistry {

    private var skills: [String: any Skill] = [:]

    public init() {}

    /// Registers a skill, keyed by ``Skill/identifier``. Replaces any existing skill with the same identifier.
    public func register(_ skill: some Skill) {
        skills[skill.identifier] = skill
    }

    /// Removes the skill with the given identifier. No-op if the identifier is not registered.
    public func unregister(id: String) {
        skills.removeValue(forKey: id)
    }

    /// Returns the skill registered under `id`.
    /// - Throws: ``AIError/skillNotFound(_:)`` if no skill is registered with that identifier.
    public func skill(id: String) throws(AIError) -> any Skill {
        guard let skill = skills[id] else {
            throw AIError.skillNotFound(id)
        }
        return skill
    }

    /// All currently registered skills, in unspecified order.
    public var allSkills: [any Skill] {
        Array(skills.values)
    }
}
