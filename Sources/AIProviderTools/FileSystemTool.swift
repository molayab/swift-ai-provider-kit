// Direct filesystem access is intentionally limited to macOS in this package.
// On iOS/visionOS, sandbox restrictions make arbitrary path access unsafe for
// a general-purpose library tool; app-specific file coordination belongs in
// the host app, not here.
#if os(macOS)
import AIProviderKit
import Foundation

/// A `ToolGroup` for basic file I/O and directory listing on macOS.
///
/// Provides three atomic operations the model can call independently:
/// - `read_file`       — reads a UTF-8 text file and returns its content
/// - `write_file`      — writes (or overwrites) a UTF-8 text file
/// - `list_directory`  — returns the names and types of entries in a directory
///
/// ```swift
/// #if os(macOS)
/// await client.toolRegistry.registerAll(FileSystemTool.self)
/// #endif
/// ```
///
/// Paths may use the `~` home-directory prefix. All operations use
/// `FileManager.default` and `Foundation` string I/O — no subprocess needed.
///
/// - Note: These tools give the model unrestricted read/write access to the
///   filesystem within the running user's permissions. Only register them in
///   developer-facing or automation contexts you control.
public enum FileSystemTool: ToolGroup {

    /// All tools in this group.
    public static var all: [Tool] { [readFile, writeFile, listDirectory] }

    // MARK: - read_file

    public static let readFile = Tool(
        name: "read_file",
        description: """
        Reads the UTF-8 text content of a file and returns it as a string. \
        Use to inspect source code, configuration files, logs, or any plain-text file.
        """,
        inputSchema: .object(
            properties: [
                "path": .string(description: "Absolute or home-relative (~) path to the file to read.")
            ],
            required: ["path"]
        )
    ) { input in
        guard let rawPath = input["path"]?.stringValue, !rawPath.isEmpty else {
            return .object(["error": "Missing required parameter: path"])
        }
        let path = (rawPath as NSString).expandingTildeInPath
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            return .object([
                "content": .string(content),
                "bytes":   .integer(content.utf8.count)
            ])
        } catch {
            return .object(["error": .string(error.localizedDescription)])
        }
    }

    // MARK: - write_file

    public static let writeFile = Tool(
        name: "write_file",
        description: """
        Writes text to a file, creating it if it does not exist and overwriting \
        if it does. Optionally creates missing parent directories.
        """,
        inputSchema: .object(
            properties: [
                "path":              .string(description: "Absolute or home-relative (~) path to write."),
                "content":           .string(description: "UTF-8 text content to write."),
                "createDirectories": .boolean(description: "Create missing parent directories. Default: false.")
            ],
            required: ["path", "content"]
        )
    ) { input in
        guard let rawPath = input["path"]?.stringValue, !rawPath.isEmpty else {
            return .object(["error": "Missing required parameter: path"])
        }
        guard let content = input["content"]?.stringValue else {
            return .object(["error": "Missing required parameter: content"])
        }
        let path       = (rawPath as NSString).expandingTildeInPath
        let createDirs = input["createDirectories"]?.boolValue ?? false

        if createDirs {
            let dir = (path as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )
        }

        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return .object([
                "success": true,
                "bytes":   .integer(content.utf8.count)
            ])
        } catch {
            return .object(["error": .string(error.localizedDescription)])
        }
    }

    // MARK: - list_directory

    public static let listDirectory = Tool(
        name: "list_directory",
        description: """
        Returns the names and types (file / directory) of entries in a directory. \
        Use to explore project structure, locate files, or verify that a write succeeded.
        """,
        inputSchema: .object(
            properties: [
                "path":          .string(description: "Absolute or home-relative (~) path. Defaults to the current working directory."),
                "includeHidden": .boolean(description: "Include dot-files and dot-directories. Default: false.")
            ]
        )
    ) { input in
        let rawPath      = input["path"]?.stringValue ?? FileManager.default.currentDirectoryPath
        let path         = (rawPath as NSString).expandingTildeInPath
        let includeHidden = input["includeHidden"]?.boolValue ?? false

        do {
            let names    = try FileManager.default.contentsOfDirectory(atPath: path)
            let filtered = includeHidden ? names : names.filter { !$0.hasPrefix(".") }
            let items: [JSONValue] = filtered.sorted().map { name in
                let full = (path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: full, isDirectory: &isDir)
                return .object([
                    "name": .string(name),
                    "type": .string(isDir.boolValue ? "directory" : "file")
                ])
            }
            return .object([
                "path":    .string(path),
                "entries": .array(items)
            ])
        } catch {
            return .object(["error": .string(error.localizedDescription)])
        }
    }
}

#endif
