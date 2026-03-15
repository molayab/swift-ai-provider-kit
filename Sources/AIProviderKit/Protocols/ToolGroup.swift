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
/// For groups that vend exactly one tool, the `tool()` function gives direct
/// access without going through `all`:
///
/// ```swift
/// let tool = try CurrentTimeTool.tool()
/// ```
public protocol ToolGroup {
    /// All tools provided by this group. Must not be empty.
    static var all: [Tool] { get }
}

public extension ToolGroup {
    /// Returns the single tool in this group.
    ///
    /// Throws `ToolGroupError.empty` if `all` is empty. In debug builds, calling
    /// this on a multi-tool group additionally triggers an `assertionFailure`; in
    /// release builds it silently returns the first tool. Use `all` or
    /// `registerAll(_:)` for groups that expose more than one tool.
    static func tool() throws -> Tool {
        guard let first = all.first else {
            throw ToolGroupError.empty(groupType: "\(Self.self)")
        }
        assert(
            all.count == 1,
            "\(Self.self).tool() requires all.count == 1 (found \(all.count)). Use all or registerAll(_:) instead."
        )
        return first
    }
}

/// Errors thrown by ``ToolGroup/tool()``.
public enum ToolGroupError: Error, CustomStringConvertible {
    /// The group's `all` array is empty, violating the protocol contract.
    case empty(groupType: String)

    public var description: String {
        switch self {
        case .empty(let type):
            return "\(type).all must not be empty"
        }
    }
}
