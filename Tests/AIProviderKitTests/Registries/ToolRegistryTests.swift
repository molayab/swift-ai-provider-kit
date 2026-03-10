import Testing
@testable import AIProviderKit

@Suite("ToolRegistry")
struct ToolRegistryTests {

    private func makeTool(name: String = "test_tool") -> Tool {
        Tool(
            name: name,
            description: "A test tool named \(name)",
            inputSchema: .object(properties: ["x": .string()], required: ["x"])
        ) { input async throws in
            .string("result from \(name)")
        }
    }

    // MARK: - Register and Retrieve

    @Test("register then tool(named:) returns correct tool")
    func register_thenToolNamed_returnsCorrectTool() async throws {
        // Given
        let registry = ToolRegistry()
        let tool = makeTool(name: "weather")

        // When
        await registry.register(tool)
        let retrieved = try await registry.tool(named: "weather")

        // Then
        #expect(retrieved.name == "weather")
    }

    @Test("tool(named:) throws toolNotFound for unknown name")
    func toolNamed_unknownName_throwsToolNotFound() async {
        // Given
        let registry = ToolRegistry()

        // When / Then
        await #expect(throws: AIError.self) {
            try await registry.tool(named: "nonexistent")
        }
    }

    // MARK: - Unregister

    @Test("unregister removes a previously registered tool")
    func unregister_removesRegisteredTool() async {
        // Given
        let registry = ToolRegistry()
        await registry.register(makeTool(name: "removeme"))

        // When
        await registry.unregister(named: "removeme")

        // Then
        await #expect(throws: AIError.self) {
            try await registry.tool(named: "removeme")
        }
    }

    @Test("unregister on non-existent name does not throw")
    func unregister_nonExistentName_doesNotThrow() async {
        // Given
        let registry = ToolRegistry()

        // When / Then (should not throw)
        await registry.unregister(named: "ghost")
    }

    // MARK: - allTools

    @Test("allTools returns all registered tools")
    func allTools_returnsAllRegistered() async {
        // Given
        let registry = ToolRegistry()
        await registry.register(makeTool(name: "alpha"))
        await registry.register(makeTool(name: "beta"))

        // When
        let all = await registry.allTools

        // Then
        #expect(all.count == 2)
        let names = Set(all.map(\.name))
        #expect(names.contains("alpha"))
        #expect(names.contains("beta"))
    }

    @Test("allTools returns empty array when no tools registered")
    func allTools_noTools_returnsEmpty() async {
        // Given
        let registry = ToolRegistry()

        // When
        let all = await registry.allTools

        // Then
        #expect(all.isEmpty)
    }

    // MARK: - Execute

    @Test("execute calls the handler and returns result")
    func execute_callsHandlerAndReturnsResult() async throws {
        // Given
        let registry = ToolRegistry()
        let tool = Tool(
            name: "echo",
            description: "Echoes input",
            inputSchema: .object(properties: ["msg": .string()])
        ) { input async throws in
            input
        }
        await registry.register(tool)

        // When
        let result = try await registry.execute(toolName: "echo", input: .string("ping"))

        // Then
        #expect(result == .string("ping"))
    }

    @Test("execute throws toolNotFound for unknown tool name")
    func execute_unknownTool_throwsToolNotFound() async {
        // Given
        let registry = ToolRegistry()

        // When / Then
        await #expect(throws: AIError.self) {
            try await registry.execute(toolName: "missing", input: .null)
        }
    }

    @Test("execute propagates handler errors")
    func execute_handlerThrows_propagatesError() async {
        // Given
        struct HandlerError: Error {}
        let registry = ToolRegistry()
        let tool = Tool(
            name: "failing",
            description: "Always fails",
            inputSchema: .object()
        ) { _ async throws -> JSONValue in
            throw HandlerError()
        }
        await registry.register(tool)

        // When / Then
        await #expect(throws: HandlerError.self) {
            try await registry.execute(toolName: "failing", input: .null)
        }
    }

    // MARK: - Re-registration

    @Test("registering a tool with the same name replaces the previous one")
    func register_sameName_replacesPrevious() async throws {
        // Given
        let registry = ToolRegistry()
        let original = Tool(
            name: "tool",
            description: "Original",
            inputSchema: .object()
        ) { _ async throws in .string("original") }
        let replacement = Tool(
            name: "tool",
            description: "Replacement",
            inputSchema: .object()
        ) { _ async throws in .string("replacement") }

        // When
        await registry.register(original)
        await registry.register(replacement)
        let result = try await registry.execute(toolName: "tool", input: .null)

        // Then
        #expect(result == .string("replacement"))
    }
}
