import Foundation
import AIProviderKit

// `Process` is macOS-only. It is not available on iOS, watchOS, tvOS, or
// visionOS — those platforms prohibit subprocess launching for security reasons.
// No change to this restriction was introduced in the iOS 26 / macOS 26 SDK.
#if os(macOS)

/// A `Tool` that lets the model run a shell command and read its output.
///
/// Only available on macOS. Sandboxed Mac App Store targets cannot use this
/// tool — `Process` requires entitlements that the App Store does not permit
/// for arbitrary subprocess execution.
///
/// ```swift
/// await client.toolRegistry.register(AIProviderTools.shellCommand)
/// ```
///
/// - Note: This tool is intentionally unrestricted. Only register it in
///   contexts where you trust the model's judgment (developer CLI tools,
///   local automation). Do not expose it in user-facing production apps.
public let shellCommand = Tool(
    name: "run_shell_command",
    description: """
    Runs a shell command on macOS and returns its standard output, standard \
    error, and exit code. Use this to inspect the filesystem, run build tools, \
    query system state, or execute any command the user asks for.
    """,
    inputSchema: .object(
        properties: [
            "command": .string(description: "The shell command to execute (runs via /bin/zsh -c)."),
            "working_directory": .string(description: "Optional absolute path to use as the working directory.")
        ],
        required: ["command"]
    )
) { input in
    guard let command = input["command"]?.stringValue, !command.isEmpty else {
        return .object(["error": .string("Missing required parameter: command")])
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", command]

    if let workingDir = input["working_directory"]?.stringValue {
        process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
    }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError  = stderrPipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return .object(["error": .string("Failed to launch process: \(error.localizedDescription)")])
    }

    let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    return .object([
        "stdout":    .string(stdout),
        "stderr":    .string(stderr),
        "exit_code": .integer(Int(process.terminationStatus))
    ])
}

#endif
