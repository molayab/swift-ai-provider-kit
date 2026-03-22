@testable import OpenAIProvider
import Testing

@Suite("OpenAIConstants")
struct OpenAIConstantsTests {

    // MARK: - Endpoint URLs

    @Test("chatCompletionsURL has correct string value")
    func chatCompletionsURL_hasCorrectStringValue() throws {
        // Given
        let expectedURL = "https://api.openai.com/v1/chat/completions"

        // When
        let url = try #require(OpenAIConstants.chatCompletionsURL)

        // Then
        #expect(url.absoluteString == expectedURL)
    }

    @Test("modelsURL has correct string value")
    func modelsURL_hasCorrectStringValue() throws {
        // Given
        let expectedURL = "https://api.openai.com/v1/models"

        // When
        let url = try #require(OpenAIConstants.modelsURL)

        // Then
        #expect(url.absoluteString == expectedURL)
    }

    // MARK: - Chat Model Prefixes

    @Test("chatModelPrefixes contains gpt- prefix")
    func chatModelPrefixes_containsGPT() {
        // Given
        let prefixes = OpenAIConstants.chatModelPrefixes

        // When / Then
        #expect(prefixes.contains("gpt-"))
    }

    @Test("chatModelPrefixes contains o1 prefix")
    func chatModelPrefixes_containsO1() {
        // Given
        let prefixes = OpenAIConstants.chatModelPrefixes

        // When / Then
        #expect(prefixes.contains("o1"))
    }

    @Test("chatModelPrefixes contains o3 prefix")
    func chatModelPrefixes_containsO3() {
        // Given
        let prefixes = OpenAIConstants.chatModelPrefixes

        // When / Then
        #expect(prefixes.contains("o3"))
    }

    @Test("chatModelPrefixes contains o4 prefix")
    func chatModelPrefixes_containsO4() {
        // Given
        let prefixes = OpenAIConstants.chatModelPrefixes

        // When / Then
        #expect(prefixes.contains("o4"))
    }

    @Test("chatModelPrefixes contains chatgpt- prefix")
    func chatModelPrefixes_containsChatGPT() {
        // Given
        let prefixes = OpenAIConstants.chatModelPrefixes

        // When / Then
        #expect(prefixes.contains("chatgpt-"))
    }

    // MARK: - Excluded Model Prefixes

    @Test("excludedModelPrefixes contains text-embedding")
    func excludedModelPrefixes_containsTextEmbedding() {
        // Given
        let prefixes = OpenAIConstants.excludedModelPrefixes

        // When / Then
        #expect(prefixes.contains("text-embedding"))
    }

    @Test("excludedModelPrefixes contains whisper")
    func excludedModelPrefixes_containsWhisper() {
        // Given
        let prefixes = OpenAIConstants.excludedModelPrefixes

        // When / Then
        #expect(prefixes.contains("whisper"))
    }

    @Test("excludedModelPrefixes contains dall-e")
    func excludedModelPrefixes_containsDallE() {
        // Given
        let prefixes = OpenAIConstants.excludedModelPrefixes

        // When / Then
        #expect(prefixes.contains("dall-e"))
    }

    @Test("excludedModelPrefixes contains tts-")
    func excludedModelPrefixes_containsTTS() {
        // Given
        let prefixes = OpenAIConstants.excludedModelPrefixes

        // When / Then
        #expect(prefixes.contains("tts-"))
    }

    @Test("excludedModelPrefixes contains davinci")
    func excludedModelPrefixes_containsDavinci() {
        // Given
        let prefixes = OpenAIConstants.excludedModelPrefixes

        // When / Then
        #expect(prefixes.contains("davinci"))
    }
}
