/// Thread-safe registry for `Tool` instances.
///
/// Register tools at startup and pass `allTools` to an `AIRequest` when needed.
public actor ToolRegistry {

    private var tools: [String: Tool] = [:]

    public init() {}

    /// Registers a tool, keyed by ``Tool/name``. Replaces any existing tool with the same name.
    public func register(_ tool: Tool) {
        tools[tool.name] = tool
    }

    /// Registers all tools provided by a `ToolGroup` conforming type.
    public func registerAll(_ group: any ToolGroup.Type) {
        for tool in group.all {
            tools[tool.name] = tool
        }
    }

    /// Removes the tool with the given name. No-op if the name is not registered.
    public func unregister(named name: String) {
        tools.removeValue(forKey: name)
    }

    /// Returns the tool registered under `name`.
    /// - Throws: ``AIError/toolNotFound(_:)`` if no tool is registered with that name.
    public func tool(named name: String) throws(AIError) -> Tool {
        guard let tool = tools[name] else {
            throw AIError.toolNotFound(name)
        }
        return tool
    }

    /// All currently registered tools, in unspecified order.
    public var allTools: [Tool] {
        Array(tools.values)
    }

    /// Looks up and executes the named tool with the given input.
    /// - Throws: ``AIError/toolNotFound(_:)`` if the name is not registered, or
    ///   ``AIError/toolExecutionFailed(toolName:underlying:)`` if the handler throws.
    public func execute(toolName: String, input: JSONValue) async throws(AIError) -> JSONValue {
        let tool = try tool(named: toolName)
        do {
            return try await tool.execute(with: input)
        } catch {
            throw AIError.toolExecutionFailed(toolName: toolName, underlying: error)
        }
    }
}
