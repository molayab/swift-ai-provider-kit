@testable import AIProviderKit
import Foundation
import Testing

@Suite("ContentBlock")
struct ContentBlockTests {

    // MARK: - textValue

    @Test("textValue returns string for text block")
    func textValue_textBlock_returnsString() {
        // Given
        let block = ContentBlock.text("Hello")

        // When
        let result = block.textValue

        // Then
        #expect(result == "Hello")
    }

    @Test("textValue returns nil for image block")
    func textValue_imageBlock_returnsNil() {
        // Given
        let block = ContentBlock.image(.init(source: .url("https://example.com/img.png")))

        // When
        let result = block.textValue

        // Then
        #expect(result == nil)
    }

    @Test("textValue returns nil for toolUse block")
    func textValue_toolUseBlock_returnsNil() {
        // Given
        let block = ContentBlock.toolUse(.init(id: "t1", name: "tool", input: .null))

        // When
        let result = block.textValue

        // Then
        #expect(result == nil)
    }

    @Test("textValue returns nil for toolResult block")
    func textValue_toolResultBlock_returnsNil() {
        // Given
        let block = ContentBlock.toolResult(.init(toolUseId: "t1", content: [.text("ok")]))

        // When
        let result = block.textValue

        // Then
        #expect(result == nil)
    }

    // MARK: - Equatable

    @Test("two identical text blocks are equal")
    func equatable_identicalTextBlocks_areEqual() {
        // Given
        let lhs = ContentBlock.text("Same")
        let rhs = ContentBlock.text("Same")

        // When / Then
        #expect(lhs == rhs)
    }

    @Test("two different text blocks are not equal")
    func equatable_differentTextBlocks_areNotEqual() {
        // Given
        let lhs = ContentBlock.text("A")
        let rhs = ContentBlock.text("B")

        // When / Then
        #expect(lhs != rhs)
    }

    @Test("text block and toolUse block are not equal")
    func equatable_textAndToolUse_areNotEqual() {
        // Given
        let lhs = ContentBlock.text("hello")
        let rhs = ContentBlock.toolUse(.init(id: "t1", name: "tool", input: .null))

        // When / Then
        #expect(lhs != rhs)
    }

    // MARK: - ToolUseContent Construction

    @Test("ToolUseContent stores all properties correctly")
    func toolUseContent_storesProperties() {
        // Given
        let input: JSONValue = ["city": "Rome"]

        // When
        let content = ContentBlock.ToolUseContent(id: "t1", name: "get_weather", input: input)

        // Then
        #expect(content.id == "t1")
        #expect(content.name == "get_weather")
        #expect(content.input["city"]?.stringValue == "Rome")
    }

    // MARK: - ToolResultContent Construction

    @Test("ToolResultContent stores all properties correctly")
    func toolResultContent_storesProperties() {
        // Given / When
        let content = ContentBlock.ToolResultContent(
            toolUseId: "t1",
            content: [.text("Result text")],
            isError: true
        )

        // Then
        #expect(content.toolUseId == "t1")
        #expect(content.content.count == 1)
        #expect(content.content[0].textValue == "Result text")
        #expect(content.isError == true)
    }

    @Test("ToolResultContent defaults isError to false")
    func toolResultContent_defaultsIsErrorToFalse() {
        // Given / When
        let content = ContentBlock.ToolResultContent(
            toolUseId: "t1",
            content: [.text("ok")]
        )

        // Then
        #expect(content.isError == false)
    }

    // MARK: - ImageContent Construction

    @Test("ImageContent with base64 source stores data")
    func imageContent_base64Source_storesData() {
        // Given
        let data = Data("image-data".utf8)

        // When
        let content = ContentBlock.ImageContent(source: .base64(mediaType: "image/png", data: data))

        // Then
        if case .base64(let mediaType, let storedData) = content.source {
            #expect(mediaType == "image/png")
            #expect(storedData == data)
        } else {
            Issue.record("Expected base64 source")
        }
    }

    @Test("ImageContent with url source stores url string")
    func imageContent_urlSource_storesUrl() {
        // Given / When
        let content = ContentBlock.ImageContent(source: .url("https://example.com/img.png"))

        // Then
        if case .url(let urlString) = content.source {
            #expect(urlString == "https://example.com/img.png")
        } else {
            Issue.record("Expected url source")
        }
    }
}
