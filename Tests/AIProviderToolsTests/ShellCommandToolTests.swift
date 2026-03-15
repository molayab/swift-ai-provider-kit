import Testing
import AIProviderKit
import AIProviderTools

// `shellCommand` is macOS-only — guard the entire suite.
#if os(macOS)

@Suite("ShellCommandTool")
struct ShellCommandToolTests {

    // MARK: - Metadata

    @Test("tool has correct name")
    func name() {
        #expect(AIProviderTools.shellCommand.name == "run_shell_command")
    }

    @Test("tool has non-empty description")
    func descriptionIsNonEmpty() {
        #expect(!AIProviderTools.shellCommand.description.isEmpty)
    }

    @Test("input schema requires command parameter")
    func inputSchemaRequiresCommand() {
        // given
        let schema: JSONSchema = AIProviderTools.shellCommand.inputSchema

        // then
        guard case .object(let properties, let required, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(properties["command"] != nil)
        #expect(required?.contains("command") == true)
    }

    @Test("input schema has optional working_directory parameter")
    func inputSchemaOptionalWorkingDirectory() {
        // given
        let schema: JSONSchema = AIProviderTools.shellCommand.inputSchema

        // then
        guard case .object(let properties, _, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(properties["working_directory"] != nil)
    }

    // MARK: - Execution

    @Test("echo command returns stdout")
    func echoCommand() async throws {
        // given
        let input: JSONValue = .object(["command": .string("echo hello")])

        // when
        let result = try await AIProviderTools.shellCommand.execute(with: input)

        // then
        guard case .object(let dict) = result else {
            Issue.record("Expected object result")
            return
        }
        #expect(dict["exit_code"] == .integer(0))
        guard case .string(let stdout) = dict["stdout"] else {
            Issue.record("Expected stdout string")
            return
        }
        #expect(stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
    }

    @Test("failing command returns non-zero exit code and stderr")
    func failingCommand() async throws {
        // given
        let input: JSONValue = .object(["command": .string("ls /nonexistent_path_xyz")])

        // when
        let result = try await AIProviderTools.shellCommand.execute(with: input)

        // then
        guard case .object(let dict) = result else {
            Issue.record("Expected object result")
            return
        }
        guard case .integer(let code) = dict["exit_code"] else {
            Issue.record("Expected integer exit_code")
            return
        }
        #expect(code != 0)
        guard case .string(let stderr) = dict["stderr"] else {
            Issue.record("Expected stderr string")
            return
        }
        #expect(!stderr.isEmpty)
    }

    @Test("missing command parameter returns error object")
    func missingCommand() async throws {
        // given
        let input: JSONValue = .object([:])

        // when
        let result = try await AIProviderTools.shellCommand.execute(with: input)

        // then
        guard case .object(let dict) = result else {
            Issue.record("Expected object result")
            return
        }
        #expect(dict["error"] != nil)
    }

    @Test("working_directory parameter is respected")
    func workingDirectoryParameter() async throws {
        // given
        let input: JSONValue = .object([
            "command": .string("pwd"),
            "working_directory": .string("/tmp")
        ])

        // when
        let result = try await AIProviderTools.shellCommand.execute(with: input)

        // then
        guard case .object(let dict) = result,
              case .string(let stdout) = dict["stdout"] else {
            Issue.record("Expected stdout string")
            return
        }
        // /tmp may be symlinked to /private/tmp on macOS
        #expect(stdout.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("tmp"))
    }
}

#endif
