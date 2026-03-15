// `Process` and `osascript` are macOS-only.
#if os(macOS)
import AIProviderKit
import Foundation

/// A `ToolGroup` that lets the model execute AppleScript on macOS.
///
/// Scripts are passed via `osascript -` (stdin), which supports multi-line
/// source without shell-escaping issues. The tool returns the script's
/// string result on success, or an error message on failure.
///
/// ```swift
/// #if os(macOS)
/// await client.toolRegistry.registerAll(AppleScriptTool.self)
/// #endif
/// ```
///
/// - Note: AppleScript can control any scriptable app and perform system-level
///   automation. Only register this tool in trusted, developer-facing contexts.
public enum AppleScriptTool: ToolGroup {

    /// All tools in this group (exactly one).
    public static var all: [Tool] { [runScript] }

    // MARK: - Tool

    public static let runScript = Tool(
        name: "run_applescript",
        description: """
        Executes an AppleScript and returns its result. Use to control macOS \
        applications (Finder, Mail, Safari, System Events, …), automate UI \
        interactions, show dialogs, query app state, manage windows, send \
        keystrokes, and perform system-level automation. Multi-line scripts \
        are supported.
        """,
        inputSchema: .object(
            properties: [
                "script": .string(description: "AppleScript source code to execute. May span multiple lines.")
            ],
            required: ["script"]
        )
    ) { input in
        guard let script = input["script"]?.stringValue, !script.isEmpty else {
            return .object(["error": "Missing required parameter: script"])
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"] // read script from stdin

        let stdinPipe  = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput  = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError  = stderrPipe

        do {
            try process.run()
        } catch {
            return .object(["error": .string("Failed to launch osascript: \(error.localizedDescription)")])
        }

        // Write script to stdin then close so osascript gets EOF.
        if let scriptData = script.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(scriptData)
        }
        stdinPipe.fileHandleForWriting.closeFile()

        // Drain both output pipes concurrently to prevent pipe-buffer deadlock.
        let (outData, errData) = await withTaskCancellationHandler {
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
            return await (stdoutData, stderrData)
        } onCancel: {
            process.terminate()
        }
        process.waitUntilExit()

        let exitCode = Int(process.terminationStatus)
        let output   = String(data: outData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errOutput = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if exitCode == 0 {
            return .object([
                "result": .string(output),
                "exit_code": .integer(exitCode)
            ])
        } else {
            let message = errOutput.isEmpty
                ? "Script failed with exit code \(exitCode)"
                : errOutput
            return .object([
                "error": .string(message),
                "exit_code": .integer(exitCode)
            ])
        }
    }
}

#endif
