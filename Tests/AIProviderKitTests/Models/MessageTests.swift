import Testing
@testable import AIProviderKit

@Suite("Message")
struct MessageTests {

    // MARK: - Factory Methods

    @Test("user factory sets role to user and content to text")
    func user_factoryMethod_setsRoleAndContent() {
        // Given / When
        let message = Message.user(text: "Hello")

        // Then
        #expect(message.role == .user)
        #expect(message.content.count == 1)
        #expect(message.content[0].textValue == "Hello")
    }

    @Test("assistant factory sets role to assistant and content to text")
    func assistant_factoryMethod_setsRoleAndContent() {
        // Given / When
        let message = Message.assistant(text: "Hi there")

        // Then
        #expect(message.role == .assistant)
        #expect(message.content.count == 1)
        #expect(message.content[0].textValue == "Hi there")
    }

    @Test("system factory sets role to system and content to text")
    func system_factoryMethod_setsRoleAndContent() {
        // Given / When
        let message = Message.system("You are helpful.")

        // Then
        #expect(message.role == .system)
        #expect(message.content.count == 1)
        #expect(message.content[0].textValue == "You are helpful.")
    }

    // MARK: - Text Convenience Property

    @Test("text concatenates all text content blocks")
    func text_multipleTextBlocks_concatenates() {
        // Given
        let message = Message(role: .user, content: [
            .text("Hello "),
            .text("world")
        ])

        // When
        let result = message.text

        // Then
        #expect(result == "Hello world")
    }

    @Test("text returns empty string when no text blocks")
    func text_noTextBlocks_returnsEmpty() {
        // Given
        let message = Message(role: .user, content: [
            .toolUse(.init(id: "t1", name: "tool", input: .null))
        ])

        // When
        let result = message.text

        // Then
        #expect(result == "")
    }

    @Test("text skips non-text content blocks")
    func text_mixedContent_skipsNonText() {
        // Given
        let message = Message(role: .assistant, content: [
            .text("Answer: "),
            .toolUse(.init(id: "t1", name: "calc", input: .null)),
            .text("42")
        ])

        // When
        let result = message.text

        // Then
        #expect(result == "Answer: 42")
    }

    // MARK: - Result Builder

    @Test("user result builder constructs correct content array")
    func userResultBuilder_constructsCorrectContentArray() {
        // Given / When
        let message = Message.user {
            ContentBlock.text("Hello")
            ContentBlock.text("World")
        }

        // Then
        #expect(message.role == .user)
        #expect(message.content.count == 2)
        #expect(message.content[0].textValue == "Hello")
        #expect(message.content[1].textValue == "World")
    }

    @Test("assistant result builder constructs correct content array")
    func assistantResultBuilder_constructsCorrectContentArray() {
        // Given / When
        let message = Message.assistant {
            ContentBlock.text("Response")
        }

        // Then
        #expect(message.role == .assistant)
        #expect(message.content.count == 1)
    }

    // MARK: - Init with Content Array

    @Test("init with role and content array stores values")
    func init_roleAndContentArray_storesValues() {
        // Given
        let blocks: [ContentBlock] = [.text("A"), .text("B")]

        // When
        let message = Message(role: .assistant, content: blocks)

        // Then
        #expect(message.role == .assistant)
        #expect(message.content.count == 2)
    }

    // MARK: - Equatable

    @Test("identical messages are equal")
    func equatable_identicalMessages_areEqual() {
        // Given
        let a = Message.user(text: "Hi")
        let b = Message.user(text: "Hi")

        // When / Then
        #expect(a == b)
    }

    @Test("different messages are not equal")
    func equatable_differentMessages_areNotEqual() {
        // Given
        let a = Message.user(text: "Hi")
        let b = Message.assistant(text: "Hi")

        // When / Then
        #expect(a != b)
    }
}
