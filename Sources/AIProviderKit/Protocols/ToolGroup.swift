/// A type that vends one or more related `Tool`s under a common interface.
///
/// Every tool in `AIProviderTools` — whether it wraps a single operation or a
/// family of related operations — conforms to `ToolGroup`. This lets callers
/// use a single registration API regardless of cardinality:
///
/// ```swift
/// import AIProviderTools
///
/// // Single-tool groups
/// await client.toolRegistry.registerAll(CurrentTimeTool.self)
///
/// #if os(macOS)
/// await client.toolRegistry.registerAll(ShellCommandTool.self)
/// #endif
///
/// // Multi-tool groups
/// await client.toolRegistry.registerAll(CalendarTool.self)
/// await client.toolRegistry.registerAll(RemindersTool.self)
/// await client.toolRegistry.registerAll(LocationTool.self)
/// ```
///
/// For groups that vend exactly one tool, the `tool` extension property gives
/// direct access without going through `all`:
///
/// ```swift
/// let tool = CurrentTimeTool.tool
/// ```
public protocol ToolGroup {
    /// All tools provided by this group. Must not be empty.
    static var all: [Tool] { get }
}

public extension ToolGroup {
    /// Direct accessor for `ToolGroup` types that vend exactly one tool.
    ///
    /// Calling this on a multi-tool group returns the first tool. Prefer
    /// using `all` when you need every tool in the group.
    static var tool: Tool {
        guard let first = all.first else {
            preconditionFailure("\(Self.self).all must not be empty")
        }
        return first
    }
}
