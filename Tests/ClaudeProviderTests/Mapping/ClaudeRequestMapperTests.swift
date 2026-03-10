import Testing
import Foundation
import AIProviderKit
@testable import ClaudeProvider

@Suite("ClaudeRequestMapper")
struct ClaudeRequestMapperTests {

    let sut = ClaudeRequestMapper()

    // MARK: - Helpers

    private func makeRequest(
        messages: [Message] = [.user(text: "Hello")],
        model: AIModel = "test-model",
        systemPrompt: String? = nil,
        tools: [Tool] = [],
        stopSequences: [String] = []
    ) -> AIRequest {
        AIRequest(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            tools: tools,
            maxTokens: 1024,
            stopSequences: stopSequences
        )
    }

    // MARK: - Text Message Mapping

    @Test("text message maps to ClaudeMessage with type text")
    func textMessage_mapsToClaudeMessageWithTypeText() {
        // Given
        let request = makeRequest(messages: [.user(text: "Hello")])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.messages.count == 1)
        #expect(result.messages[0].role == "user")
        #expect(result.messages[0].content[0].type == "text")
        #expect(result.messages[0].content[0].text == "Hello")
    }

    // MARK: - System Message Filtering

    @Test("system role message is filtered out and system text goes in top-level system field")
    func systemMessage_filteredAndMappedToTopLevel() {
        // Given
        let request = makeRequest(
            messages: [
                .system("Be helpful."),
                .user(text: "Hi")
            ],
            systemPrompt: "Be helpful."
        )

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.system == "Be helpful.")
        let roles = result.messages.map(\.role)
        #expect(!roles.contains("system"))
        #expect(result.messages.count == 1)
        #expect(result.messages[0].role == "user")
    }

    // MARK: - Tool Mapping

    @Test("tool is mapped to ClaudeTool with input_schema")
    func tool_mappedToClaudeTool() {
        // Given
        let tool = Tool(
            name: "get_weather",
            description: "Gets weather",
            inputSchema: .object(
                properties: ["city": .string(description: "City name")],
                required: ["city"]
            )
        ) { _ async throws in .null }
        let request = makeRequest(tools: [tool])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.tools?.count == 1)
        #expect(result.tools?[0].name == "get_weather")
        #expect(result.tools?[0].description == "Gets weather")
    }

    // MARK: - Image Mapping

    @Test("image with base64 source maps to ClaudeImageSource with type base64")
    func imageBase64_mapsToClaudeImageSourceBase64() {
        // Given
        let imageData = Data("fake-image".utf8)
        let imageContent = ContentBlock.ImageContent(source: .base64(mediaType: "image/png", data: imageData))
        let message = Message(role: .user, content: [.image(imageContent)])
        let request = makeRequest(messages: [message])

        // When
        let result = sut.map(request, stream: false)

        // Then
        let block = result.messages[0].content[0]
        #expect(block.type == "image")
        #expect(block.source?.type == "base64")
        #expect(block.source?.mediaType == "image/png")
        #expect(block.source?.data == imageData.base64EncodedString())
    }

    @Test("image with url source maps to ClaudeImageSource with type url")
    func imageUrl_mapsToClaudeImageSourceUrl() {
        // Given
        let imageContent = ContentBlock.ImageContent(source: .url("https://example.com/img.png"))
        let message = Message(role: .user, content: [.image(imageContent)])
        let request = makeRequest(messages: [message])

        // When
        let result = sut.map(request, stream: false)

        // Then
        let block = result.messages[0].content[0]
        #expect(block.type == "image")
        #expect(block.source?.type == "url")
        #expect(block.source?.url == "https://example.com/img.png")
    }

    // MARK: - Stream Flag

    @Test("stream true sets ClaudeRequest.stream to true")
    func streamTrue_setsStreamToTrue() {
        // Given
        let request = makeRequest()

        // When
        let result = sut.map(request, stream: true)

        // Then
        #expect(result.stream == true)
    }

    @Test("stream false sets ClaudeRequest.stream to false")
    func streamFalse_setsStreamToFalse() {
        // Given
        let request = makeRequest()

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.stream == false)
    }

    // MARK: - Empty Tools

    @Test("empty tools array results in nil tools in ClaudeRequest")
    func emptyTools_resultsInNilTools() {
        // Given
        let request = makeRequest(tools: [])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.tools == nil)
    }

    // MARK: - Empty Stop Sequences

    @Test("empty stopSequences results in nil stopSequences in ClaudeRequest")
    func emptyStopSequences_resultsInNilStopSequences() {
        // Given
        let request = makeRequest(stopSequences: [])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.stopSequences == nil)
    }

    @Test("non-empty stopSequences are forwarded")
    func nonEmptyStopSequences_areForwarded() {
        // Given
        let request = makeRequest(stopSequences: ["END", "STOP"])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.stopSequences == ["END", "STOP"])
    }

    // MARK: - ToolUse Content Block

    @Test("toolUse content block maps correctly")
    func toolUseContentBlock_mapsCorrectly() {
        // Given
        let toolUse = ContentBlock.toolUse(.init(id: "t1", name: "calc", input: ["x": 5]))
        let message = Message(role: .assistant, content: [toolUse])
        let request = makeRequest(messages: [.user(text: "Hi"), message])

        // When
        let result = sut.map(request, stream: false)

        // Then
        let block = result.messages[1].content[0]
        #expect(block.type == "tool_use")
        #expect(block.id == "t1")
        #expect(block.name == "calc")
    }

    // MARK: - ToolResult Content Block

    @Test("toolResult content block maps correctly")
    func toolResultContentBlock_mapsCorrectly() {
        // Given
        let toolResult = ContentBlock.toolResult(.init(
            toolUseId: "t1",
            content: [.text("42")],
            isError: false
        ))
        let message = Message(role: .user, content: [toolResult])
        let request = makeRequest(messages: [message])

        // When
        let result = sut.map(request, stream: false)

        // Then
        let block = result.messages[0].content[0]
        #expect(block.type == "tool_result")
        #expect(block.toolUseId == "t1")
        #expect(block.isError == nil) // false maps to nil
    }

    @Test("toolResult with isError true maps isError to true")
    func toolResultContentBlock_isErrorTrue_mapsCorrectly() {
        // Given
        let toolResult = ContentBlock.toolResult(.init(
            toolUseId: "t1",
            content: [.text("error occurred")],
            isError: true
        ))
        let message = Message(role: .user, content: [toolResult])
        let request = makeRequest(messages: [message])

        // When
        let result = sut.map(request, stream: false)

        // Then
        let block = result.messages[0].content[0]
        #expect(block.isError == true)
    }

    // MARK: - Model and MaxTokens

    @Test("model identifier is forwarded")
    func modelIdentifier_isForwarded() {
        // Given
        let request = makeRequest(model: "claude-sonnet-4-6")

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.model == "claude-sonnet-4-6")
    }

    @Test("maxTokens is forwarded")
    func maxTokens_isForwarded() {
        // Given
        let request = makeRequest()

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.maxTokens == 1024)
    }
}
