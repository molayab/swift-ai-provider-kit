// `pbpaste` and `pbcopy` are macOS-only CLI utilities.
#if os(macOS)
import AIProviderKit
import Foundation

/// A `ToolGroup` for reading and writing the macOS system clipboard.
///
/// Uses the `/usr/bin/pbpaste` and `/usr/bin/pbcopy` CLI utilities so no
/// AppKit dependency is needed, making it safe to use from any macOS process
/// (CLI tools, daemons, XPC services) without triggering UI framework startup.
///
/// ```swift
/// #if os(macOS)
/// await client.toolRegistry.registerAll(ClipboardTool.self)
/// #endif
/// ```
public enum ClipboardTool: ToolGroup {

    /// All tools in this group.
    public static var all: [Tool] { [getClipboard, setClipboard] }

    // MARK: - get_clipboard

    public static let getClipboard = Tool(
        name: "get_clipboard",
        description: "Returns the current text content of the macOS clipboard.",
        inputSchema: .object(properties: [:])
    ) { _ in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbpaste")
        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            return .object(["error": .string("Failed to read clipboard: \(error.localizedDescription)")])
        }

        let data = await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Data, Never>) in
                DispatchQueue.global(qos: .utility).async {
                    cont.resume(returning: pipe.fileHandleForReading.readDataToEndOfFile())
                }
            }
        } onCancel: {
            process.terminate()
        }
        process.waitUntilExit()

        let text = String(data: data, encoding: .utf8) ?? ""
        return .string(text)
    }

    // MARK: - set_clipboard

    public static let setClipboard = Tool(
        name: "set_clipboard",
        description: "Replaces the macOS clipboard contents with the given text.",
        inputSchema: .object(
            properties: [
                "text": .string(description: "Text to place on the clipboard.")
            ],
            required: ["text"]
        )
    ) { input in
        guard let text = input["text"]?.stringValue else {
            return .object(["error": "Missing required parameter: text"])
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        process.standardInput = pipe

        do {
            try process.run()
        } catch {
            return .object(["error": .string("Failed to write clipboard: \(error.localizedDescription)")])
        }

        if let data = text.data(using: .utf8) {
            pipe.fileHandleForWriting.write(data)
        }
        pipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        return .object(["success": true])
    }
}

#endif
