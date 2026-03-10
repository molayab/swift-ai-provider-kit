/// A type that vends a collection of related `Tool`s.
///
/// Conform an enum or struct to `ToolGroup` to enable bulk registration via
/// `ToolRegistry.registerAll(_:)`.
///
/// ```swift
/// await client.toolRegistry.registerAll(CalendarTool.self)
/// await client.toolRegistry.registerAll(RemindersTool.self)
/// await client.toolRegistry.registerAll(LocationTool.self)
/// ```
public protocol ToolGroup {
    /// All tools provided by this group.
    static var all: [Tool] { get }
}
