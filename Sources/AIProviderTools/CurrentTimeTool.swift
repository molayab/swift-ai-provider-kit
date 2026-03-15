import AIProviderKit
import Foundation

/// A `ToolGroup` that provides the current date, time, and timezone.
///
/// The model calls this automatically whenever the user asks about the current
/// time, date, or timezone. Supports two output formats via the optional
/// `format` parameter:
///
/// - `"iso8601"` (default) — machine-readable ISO 8601 timestamp + timezone ID.
/// - `"human"` — locale-formatted full date and time string.
///
/// Register via the unified `ToolGroup` interface:
///
/// ```swift
/// await client.toolRegistry.registerAll(CurrentTimeTool.self)
/// ```
///
/// Or access the tool directly:
///
/// ```swift
/// await client.toolRegistry.register(try CurrentTimeTool.tool())
/// ```
public enum CurrentTimeTool: ToolGroup {

    // ISO8601DateFormatter is thread-safe after initialisation (documented by Apple).
    nonisolated(unsafe) private static let iso8601 = ISO8601DateFormatter()
    private static let humanFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        fmt.timeStyle = .long
        return fmt
    }()

    /// All tools in this group (exactly one).
    public static var all: [Tool] { [currentTime] }

    // MARK: - Tool

    public static let currentTime = Tool(
        name: "get_current_time",
        description: "Returns the current date, time, and timezone. Call this whenever the user asks about time or date.",
        inputSchema: .object(
            properties: [
                "format": .string(description: #"Output format: "iso8601" (default) or "human""#)
            ],
            required: []
        )
    ) { input in
        let wantHuman = input["format"]?.stringValue?.lowercased() == "human"
        let now = Date()

        if wantHuman {
            return .string(CurrentTimeTool.humanFormatter.string(from: now))
        } else {
            let iso = CurrentTimeTool.iso8601.string(from: now)
            let tz = TimeZone.current.identifier
            return .object([
                "iso8601": .string(iso),
                "timezone": .string(tz)
            ])
        }
    }
}
