/// Thread-safe registry for `Skill` instances.
public actor SkillRegistry {

    private var skills: [String: any Skill] = [:]

    public init() {}

    public func register(_ skill: some Skill) {
        skills[skill.identifier] = skill
    }

    public func unregister(id: String) {
        skills.removeValue(forKey: id)
    }

    public func skill(id: String) throws(AIError) -> any Skill {
        guard let skill = skills[id] else {
            throw AIError.skillNotFound(id)
        }
        return skill
    }

    public var allSkills: [any Skill] {
        Array(skills.values)
    }
}
