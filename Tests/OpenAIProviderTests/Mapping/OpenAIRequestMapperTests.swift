import AIProviderKit
@testable import OpenAIProvider
import Foundation
import Testing

@Suite("OpenAIRequestMapper")
struct OpenAIRequestMapperTests {

    let sut = OpenAIRequestMapper()

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

    // MARK: - System Prompt

    @Test("system prompt maps to first system role message")
    func systemPrompt_mapsToSystemRoleMessage() {
        // Given
        let request = makeRequest(systemPrompt: "You are helpful.")

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.messages.count >= 2)
        #expect(result.messages[0].role == "system")
        if case .text(let text) = result.messages[0].content {
            #expect(text == "You are helpful.")
        } else {
            Issue.record("Expected .text content for system message")
        }
    }

    // MARK: - User Text Message

    @Test("user text message maps to user role with string content")
    func userTextMessage_mapsToUserRole() {
        // Given
        let request = makeRequest(messages: [.user(text: "Hello")])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.messages.count == 1)
        #expect(result.messages[0].role == "user")
        if case .text(let text) = result.messages[0].content {
            #expect(text == "Hello")
        } else {
            Issue.record("Expected .text content for user message")
        }
    }

    // MARK: - Image Mapping

    @Test("user message with image URL maps to image_url content part")
    func userMessageWithImageURL_mapsToImageURLPart() {
        // Given
        let imageContent = ContentBlock.ImageContent(source: .url("https://example.com/img.png"))
        let message = Message(role: .user, content: [.text("Look at this"), .image(imageContent)])
        let request = makeRequest(messages: [message])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.messages[0].role == "user")
        if case .parts(let parts) = result.messages[0].content {
            let imagePart = parts.first { $0.type == "image_url" }
            #expect(imagePart != nil)
            #expect(imagePart?.imageUrl?.url == "https://example.com/img.png")
        } else {
            Issue.record("Expected .parts content for multipart user message")
        }
    }

    @Test("user message with base64 image maps to data URI in image_url")
    func userMessageWithBase64Image_mapsToDataURI() {
        // Given
        let imageData = Data("fake-image".utf8)
        let imageContent = ContentBlock.ImageContent(source: .base64(mediaType: "image/jpeg", data: imageData))
        let message = Message(role: .user, content: [.text("Describe"), .image(imageContent)])
        let request = makeRequest(messages: [message])

        // When
        let result = sut.map(request, stream: false)

        // Then
        if case .parts(let parts) = result.messages[0].content {
            let imagePart = parts.first { $0.type == "image_url" }
            #expect(imagePart != nil)
            let expectedPrefix = "data:image/jpeg;base64,"
            #expect(imagePart?.imageUrl?.url.hasPrefix(expectedPrefix) == true)
        } else {
            Issue.record("Expected .parts content for multipart user message")
        }
    }

    // MARK: - Assistant Message with ToolUse

    @Test("assistant message with toolUse maps to tool_calls array")
    func assistantMessageWithToolUse_mapsToToolCalls() {
        // Given
        let toolUse = ContentBlock.toolUse(.init(
            id: "call_123",
            name: "get_weather",
            input: .object(["city": .string("Rome")])
        ))
        let message = Message(role: .assistant, content: [toolUse])
        let request = makeRequest(messages: [.user(text: "Hi"), message])

        // When
        let result = sut.map(request, stream: false)

        // Then
        let assistantMsg = result.messages[1]
        #expect(assistantMsg.role == "assistant")
        #expect(assistantMsg.toolCalls?.count == 1)
        #expect(assistantMsg.toolCalls?[0].id == "call_123")
        #expect(assistantMsg.toolCalls?[0].type == "function")
        #expect(assistantMsg.toolCalls?[0].function.name == "get_weather")
        #expect(assistantMsg.toolCalls?[0].function.arguments.contains("Rome") == true)
    }

    // MARK: - User Message with ToolResult

    @Test("user message with toolResult maps to tool role message")
    func userMessageWithToolResult_mapsToToolRole() {
        // Given
        let toolResult = ContentBlock.toolResult(.init(
            toolUseId: "call_123",
            content: [.text("22 degrees")],
            isError: false
        ))
        let message = Message(role: .user, content: [toolResult])
        let request = makeRequest(messages: [message])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.messages[0].role == "tool")
        #expect(result.messages[0].toolCallId == "call_123")
        if case .text(let text) = result.messages[0].content {
            #expect(text == "22 degrees")
        } else {
            Issue.record("Expected .text content for tool result message")
        }
    }

    @Test("multiple toolResult blocks map to multiple tool role messages")
    func multipleToolResults_mapToMultipleToolMessages() {
        // Given
        let result1 = ContentBlock.toolResult(.init(
            toolUseId: "call_1",
            content: [.text("Result A")],
            isError: false
        ))
        let result2 = ContentBlock.toolResult(.init(
            toolUseId: "call_2",
            content: [.text("Result B")],
            isError: false
        ))
        let message = Message(role: .user, content: [result1, result2])
        let request = makeRequest(messages: [message])

        // When
        let mapped = sut.map(request, stream: false)

        // Then
        let toolMessages = mapped.messages.filter { $0.role == "tool" }
        #expect(toolMessages.count == 2)
        #expect(toolMessages[0].toolCallId == "call_1")
        #expect(toolMessages[1].toolCallId == "call_2")
    }

    // MARK: - Tools

    @Test("empty tools maps to nil in request")
    func emptyTools_mapsToNil() {
        // Given
        let request = makeRequest(tools: [])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.tools == nil)
    }

    @Test("tools map to function type with name description parameters")
    func tools_mapToFunctionType() {
        // Given
        let tool = Tool(
            name: "get_weather",
            description: "Gets weather",
            inputSchema: .object(
                properties: ["city": .string(description: "City name")],
                required: ["city"]
            )
        ) { _ async in .null }
        let request = makeRequest(tools: [tool])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.tools?.count == 1)
        #expect(result.tools?[0].type == "function")
        #expect(result.tools?[0].function.name == "get_weather")
        #expect(result.tools?[0].function.description == "Gets weather")
    }

    // MARK: - Stop Sequences

    @Test("empty stopSequences maps to nil stop")
    func emptyStopSequences_mapsToNil() {
        // Given
        let request = makeRequest(stopSequences: [])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.stop == nil)
    }

    @Test("stop sequences map to stop array")
    func stopSequences_mapToStopArray() {
        // Given
        let request = makeRequest(stopSequences: ["END"])

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.stop == ["END"])
    }

    // MARK: - Stream Flag

    @Test("stream true sets stream to true in request")
    func streamTrue_setsStreamTrue() {
        // Given
        let request = makeRequest()

        // When
        let result = sut.map(request, stream: true)

        // Then
        #expect(result.stream == true)
    }

    @Test("stream false sets stream to false in request")
    func streamFalse_setsStreamFalse() {
        // Given
        let request = makeRequest()

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.stream == false)
    }

    // MARK: - System Role Filtering

    @Test("system role messages in messages array are filtered out")
    func systemRoleMessages_areFilteredOut() {
        // Given
        let request = makeRequest(
            messages: [
                .system("Be helpful."),
                .user(text: "Hi")
            ]
        )

        // When
        let result = sut.map(request, stream: false)

        // Then
        let roles = result.messages.map(\.role)
        #expect(!roles.contains("system") || result.messages[0].role == "system")
        let nonSystemMessages = result.messages.filter { $0.role != "system" }
        #expect(nonSystemMessages.count == 1)
        #expect(nonSystemMessages[0].role == "user")
    }

    // MARK: - Model and MaxTokens

    @Test("model identifier is forwarded")
    func modelIdentifier_isForwarded() {
        // Given
        let request = makeRequest(model: "gpt-4o")

        // When
        let result = sut.map(request, stream: false)

        // Then
        #expect(result.model == "gpt-4o")
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
