import Foundation
import AIProviderKit

/// A `Tool` that returns the current date, time, and timezone.
///
/// The model calls this automatically whenever the user asks about the current
/// time, date, or timezone. Supports two output formats via the optional
/// `format` parameter:
///
/// - `"iso8601"` (default) — machine-readable ISO 8601 timestamp + timezone ID.
/// - `"human"` — locale-formatted full date and time string.
///
/// ```swift
/// await client.toolRegistry.register(AIProviderTools.currentTime)
/// ```
public let currentTime = Tool(
    name: "get_current_time",
    description: "Returns the current date, time, and timezone. Call this whenever the user asks about the current time or date.",
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
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .long
        return .string(formatter.string(from: now))
    } else {
        let iso = ISO8601DateFormatter().string(from: now)
        let tz  = TimeZone.current.identifier
        return .object([
            "iso8601":  .string(iso),
            "timezone": .string(tz)
        ])
    }
}
