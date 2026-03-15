import AIProviderKit
import Foundation

// `Process` is macOS-only. It is not available on iOS, watchOS, tvOS, or
// visionOS — those platforms prohibit subprocess launching for security reasons.
// No change to this restriction was introduced in the iOS 26 / macOS 26 SDK.
#if os(macOS)

/// A `ToolGroup` that lets the model run a shell command and read its output.
///
/// Only available on macOS. Sandboxed Mac App Store targets cannot use this
/// tool — `Process` requires entitlements that the App Store does not permit
/// for arbitrary subprocess execution.
///
/// Register via the unified `ToolGroup` interface:
///
/// ```swift
/// #if os(macOS)
/// await client.toolRegistry.registerAll(ShellCommandTool.self)
/// #endif
/// ```
///
/// Or access the tool directly:
///
/// ```swift
/// #if os(macOS)
/// await client.toolRegistry.register(try ShellCommandTool.tool())
/// #endif
/// ```
///
/// - Note: This tool is intentionally unrestricted. Only register it in
///   contexts where you trust the model's judgment (developer CLI tools,
///   local automation). Do not expose it in user-facing production apps.
public enum ShellCommandTool: ToolGroup {

    /// All tools in this group (exactly one).
    public static var all: [Tool] { [shellCommand] }

    // MARK: - Tool

    public static let shellCommand = Tool(
        name: "run_shell_command",
        description: """
        Runs a shell command on macOS and returns its standard output, standard \
        error, and exit code. Use this to inspect the filesystem, run build tools, \
        query system state, or execute any command the user asks for.
        """,
        inputSchema: .object(
            properties: [
                "command": .string(description: "The shell command to execute (runs via /bin/zsh -c)."),
                "workingDirectory": .string(description: "Optional absolute path to use as the working directory.")
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

        if let workingDir = input["workingDirectory"]?.stringValue {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return .object(["error": .string("Failed to launch process: \(error.localizedDescription)")])
        }

        // Drain both pipes concurrently before calling waitUntilExit().
        // macOS pipe buffers are 64 KB; a child that writes more will block
        // on write(2) waiting for the parent to read — but the parent would
        // be stuck in waitUntilExit() if reads happen after the wait, causing
        // a deadlock. readDataToEndOfFile() is blocking, so we bridge each
        // read onto a dedicated GCD thread and drive them with async let so
        // both pipes are drained in parallel.
        async let stdoutData: Data = withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                cont.resume(returning: stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            }
        }
        async let stderrData: Data = withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                cont.resume(returning: stderrPipe.fileHandleForReading.readDataToEndOfFile())
            }
        }
        let (outData, errData) = await (stdoutData, stderrData)
        process.waitUntilExit()

        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        return .object([
            "stdout": .string(stdout),
            "stderr": .string(stderr),
            "exit_code": .integer(Int(process.terminationStatus))
        ])
    }
}

#endif
