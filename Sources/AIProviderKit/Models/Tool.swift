/// A callable tool that the model can invoke during a conversation.
///
/// Tools are provider-agnostic. The `handler` is called by `AIClient` when
/// the model requests a tool execution, and the result is fed back automatically.
///
/// ```swift
/// let weatherTool = Tool(
///     name: "get_weather",
///     description: "Returns current weather for a city.",
///     inputSchema: .object(
///         properties: ["city": .string(description: "City name")],
///         required: ["city"]
///     )
/// ) { input async throws in
///     let city = input["city"]?.stringValue ?? ""
///     return .object(["temperature": .integer(22), "condition": .string("sunny")])
/// }
/// ```
public struct Tool: Sendable {

    public let name: String
    public let description: String
    public let inputSchema: JSONSchema

    private let handler: @Sendable (JSONValue) async throws -> JSONValue

    public init(
        name: String,
        description: String,
        inputSchema: JSONSchema,
        handler: @escaping @Sendable (JSONValue) async throws -> JSONValue
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.handler = handler
    }

    /// Executes the tool with the given input and returns the result.
    public func execute(with input: JSONValue) async throws -> JSONValue {
        try await handler(input)
    }
}
