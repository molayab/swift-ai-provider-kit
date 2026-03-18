import AIProviderKit
import Foundation

/// A `ToolGroup` with utilities for verifying tool invocation during development.
///
/// Register all tools at once:
/// ```swift
/// await client.toolRegistry.registerAll(DebugTool.self)
/// ```
///
/// - `runtime_info` — returns OS, architecture, Swift, and process details.
public enum DebugTool: ToolGroup {

    public static var all: [Tool] { [runtimeInfo] }

    /// Returns environment details useful for debugging provider and platform differences.
    public static let runtimeInfo = Tool(
        name: "runtime_info",
        description: "Returns runtime environment details: OS, architecture, process ID, and locale.",
        inputSchema: .object(properties: [:], required: [])
    ) { _ in
        let processInfo = ProcessInfo.processInfo
        return .object([
            "os_name": .string(processInfo.operatingSystemVersionString),
            "process_name": .string(processInfo.processName),
            "process_id": .integer(Int(processInfo.processIdentifier)),
            "locale": .string(Locale.current.identifier),
            "timezone": .string(TimeZone.current.identifier),
            "timestamp": .string(Date().ISO8601Format()),
            "physical_memory_gb": .double(Double(processInfo.physicalMemory) / 1_073_741_824)
        ])
    }
}
