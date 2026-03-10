import AIProviderKit

enum MockData {

    static let response = AIResponse(
        id: "msg_mock_001",
        model: "mock-model",
        content: [.text("Hello from mock.")],
        usage: TokenUsage(inputTokens: 10, outputTokens: 8),
        stopReason: .endTurn
    )

    static let toolUseResponse = AIResponse(
        id: "msg_mock_002",
        model: "mock-model",
        content: [
            .toolUse(.init(
                id: "tool_001",
                name: "get_weather",
                input: ["city": "Rome"]
            ))
        ],
        usage: TokenUsage(inputTokens: 20, outputTokens: 5),
        stopReason: .toolUse
    )

    static func request(model: AIModel = "mock-model") throws -> AIRequest {
        try AIRequestBuilder()
            .model(model)
            .addMessage(.user(text: "Hello"))
            .build()
    }

    static let weatherTool = Tool(
        name: "get_weather",
        description: "Returns weather for a city.",
        inputSchema: .object(
            properties: ["city": .string(description: "City name.")],
            required: ["city"]
        )
    ) { _ async throws in
        .object(["temperature": 22, "condition": "sunny"])
    }
}
