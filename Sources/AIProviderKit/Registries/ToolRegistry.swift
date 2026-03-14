/// Thread-safe registry for `Tool` instances.
///
/// Register tools at startup and pass `allTools` to an `AIRequest` when needed.
public actor ToolRegistry {

    private var tools: [String: Tool] = [:]

    public init() {}

    public func register(_ tool: Tool) {
        tools[tool.name] = tool
    }

    /// Registers all tools provided by a `ToolGroup` conforming type.
    public func registerAll(_ group: any ToolGroup.Type) {
        for tool in group.all {
            tools[tool.name] = tool
        }
    }

    public func unregister(named name: String) {
        tools.removeValue(forKey: name)
    }

    public func tool(named name: String) throws(AIError) -> Tool {
        guard let tool = tools[name] else {
            throw AIError.toolNotFound(name)
        }
        return tool
    }

    public var allTools: [Tool] {
        Array(tools.values)
    }

    /// Executes the named tool with the given input.
    public func execute(toolName: String, input: JSONValue) async throws(AIError) -> JSONValue {
        let tool = try tool(named: toolName)
        do {
            return try await tool.execute(with: input)
        } catch {
            throw AIError.toolExecutionFailed(toolName: toolName, underlying: error)
        }
    }
}
