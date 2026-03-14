import Testing
import Foundation
import AIProviderKit
@testable import AppleIntelligenceProvider

@Suite("FMRequestMapper")
struct FMRequestMapperTests {

    // MARK: - Properties

    private let sut = FMRequestMapper()

    // MARK: - Message Mapping

    @Test("maps user message text to FMMessage")
    func map_userMessage_mapsToFMMessageWithUserRole() {
        // Given
        let request = AIRequest(
            messages: [.user(text: "Hello")],
            model: .appleIntelligenceDefault
        )

        // When
        let fmRequest = sut.map(request)

        // Then
        #expect(fmRequest.messages.count == 1)
        #expect(fmRequest.messages[0].role == "user")
        #expect(fmRequest.messages[0].content == "Hello")
    }

    @Test("maps assistant message text to FMMessage")
    func map_assistantMessage_mapsToFMMessageWithAssistantRole() {
        // Given
        let request = AIRequest(
            messages: [.assistant(text: "Hi there")],
            model: .appleIntelligenceDefault
        )

        // When
        let fmRequest = sut.map(request)

        // Then
        #expect(fmRequest.messages.count == 1)
        #expect(fmRequest.messages[0].role == "assistant")
        #expect(fmRequest.messages[0].content == "Hi there")
    }

    @Test("filters out system role messages")
    func map_systemMessage_isFiltered() {
        // Given
        let request = AIRequest(
            messages: [
                .system("You are helpful"),
                .user(text: "Hello"),
            ],
            model: .appleIntelligenceDefault
        )

        // When
        let fmRequest = sut.map(request)

        // Then
        #expect(fmRequest.messages.count == 1)
        #expect(fmRequest.messages[0].role == "user")
    }

    @Test("multiple messages are all mapped")
    func map_multipleMessages_allMapped() {
        // Given
        let request = AIRequest(
            messages: [
                .user(text: "First"),
                .assistant(text: "Second"),
                .user(text: "Third"),
            ],
            model: .appleIntelligenceDefault
        )

        // When
        let fmRequest = sut.map(request)

        // Then
        #expect(fmRequest.messages.count == 3)
        #expect(fmRequest.messages[0].content == "First")
        #expect(fmRequest.messages[1].content == "Second")
        #expect(fmRequest.messages[2].content == "Third")
    }

    // MARK: - System Prompt

    @Test("maps system prompt to FMRequest.systemPrompt")
    func map_systemPrompt_mappedToFMRequest() {
        // Given
        let request = AIRequest(
            messages: [.user(text: "Hi")],
            model: .appleIntelligenceDefault,
            systemPrompt: "Be concise."
        )

        // When
        let fmRequest = sut.map(request)

        // Then
        #expect(fmRequest.systemPrompt == "Be concise.")
    }

    // MARK: - Tools

    @Test("maps tool to FMToolDefinition with name and description")
    func map_tool_nameAndDescriptionMapped() {
        // Given
        let tool = Tool(
            name: "get_weather",
            description: "Gets weather for a city",
            inputSchema: .object(
                properties: ["city": .string(description: "City name")],
                required: ["city"]
            )
        ) { _ async throws in .null }
        let request = AIRequest(
            messages: [.user(text: "Hi")],
            model: .appleIntelligenceDefault,
            tools: [tool]
        )

        // When
        let fmRequest = sut.map(request)

        // Then
        #expect(fmRequest.tools.count == 1)
        #expect(fmRequest.tools[0].name == "get_weather")
        #expect(fmRequest.tools[0].description == "Gets weather for a city")
    }

    @Test("maps tool inputSchema to parametersSchemaJSON")
    func map_tool_inputSchemaMappedToJSON() {
        // Given
        let tool = Tool(
            name: "echo",
            description: "Echoes input",
            inputSchema: .object(
                properties: ["text": .string()],
                required: ["text"]
            )
        ) { _ async throws in .null }
        let request = AIRequest(
            messages: [.user(text: "Hi")],
            model: .appleIntelligenceDefault,
            tools: [tool]
        )

        // When
        let fmRequest = sut.map(request)

        // Then
        let json = fmRequest.tools[0].parametersSchemaJSON
        #expect(json.contains("\"type\""))
        #expect(json.contains("\"object\""))
        #expect(json.contains("\"text\""))
    }

    @Test("empty tools results in empty tools array")
    func map_noTools_emptyArray() {
        // Given
        let request = AIRequest(
            messages: [.user(text: "Hi")],
            model: .appleIntelligenceDefault,
            tools: []
        )

        // When
        let fmRequest = sut.map(request)

        // Then
        #expect(fmRequest.tools.isEmpty)
    }

    // MARK: - Temperature

    @Test("temperature is forwarded")
    func map_temperature_forwarded() {
        // Given
        let request = AIRequest(
            messages: [.user(text: "Hi")],
            model: .appleIntelligenceDefault,
            temperature: 0.7
        )

        // When
        let fmRequest = sut.map(request)

        // Then
        #expect(fmRequest.temperature == 0.7)
    }

    // MARK: - Image Content

    @Test("image content blocks are silently dropped")
    func map_imageContent_droppedSilently() {
        // Given
        let imageBlock = ContentBlock.image(
            .init(source: .base64(mediaType: "image/png", data: Data()))
        )
        let message = Message(role: .user, content: [.text("Look at this"), imageBlock])
        let request = AIRequest(
            messages: [message],
            model: .appleIntelligenceDefault
        )

        // When
        let fmRequest = sut.map(request)

        // Then
        #expect(fmRequest.messages.count == 1)
        #expect(fmRequest.messages[0].content == "Look at this")
    }
}
