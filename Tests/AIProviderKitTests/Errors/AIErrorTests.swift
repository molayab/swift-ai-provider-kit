@testable import AIProviderKit
import Foundation
import Testing

@Suite("AIError")
struct AIErrorTests {

    // MARK: - errorDescription is non-nil for every case

    @Test("authorizationFailed has a non-nil errorDescription")
    func authorizationFailed_hasDescription() {
        // Given
        let error = AIError.authorizationFailed("bad key")

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("Authorization failed") == true)
        #expect(desc?.contains("bad key") == true)
    }

    @Test("networkError has a non-nil errorDescription")
    func networkError_hasDescription() {
        // Given
        let error = AIError.networkError(URLError(.notConnectedToInternet))

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("Network error") == true)
    }

    @Test("invalidResponse has a non-nil errorDescription")
    func invalidResponse_hasDescription() {
        // Given
        let error = AIError.invalidResponse(statusCode: 500, body: "Internal Server Error")

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("500") == true)
        #expect(desc?.contains("Internal Server Error") == true)
    }

    @Test("invalidResponse with nil body shows no body")
    func invalidResponse_nilBody_showsNoBody() {
        // Given
        let error = AIError.invalidResponse(statusCode: 404, body: nil)

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("no body") == true)
    }

    @Test("decodingFailed has a non-nil errorDescription")
    func decodingFailed_hasDescription() {
        // Given
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "bad json" }
        }
        let error = AIError.decodingFailed(underlying: FakeError())

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("Decoding failed") == true)
    }

    @Test("encodingFailed has a non-nil errorDescription")
    func encodingFailed_hasDescription() {
        // Given
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "cannot encode" }
        }
        let error = AIError.encodingFailed(underlying: FakeError())

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("Encoding failed") == true)
    }

    @Test("providerUnsupported has a non-nil errorDescription")
    func providerUnsupported_hasDescription() {
        // Given
        let error = AIError.providerUnsupported(capability: .streaming)

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("does not support") == true)
    }

    @Test("toolExecutionFailed has a non-nil errorDescription")
    func toolExecutionFailed_hasDescription() {
        // Given
        struct ToolErr: Error, LocalizedError {
            var errorDescription: String? { "timeout" }
        }
        let error = AIError.toolExecutionFailed(toolName: "weather", underlying: ToolErr())

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("weather") == true)
    }

    @Test("toolNotFound has a non-nil errorDescription")
    func toolNotFound_hasDescription() {
        // Given
        let error = AIError.toolNotFound("calc")

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("Tool not found") == true)
        #expect(desc?.contains("calc") == true)
    }

    @Test("recipeRenderingFailed has a non-nil errorDescription")
    func recipeRenderingFailed_hasDescription() {
        // Given
        let error = AIError.recipeRenderingFailed(recipeId: "summarize", missingKeys: ["text", "style"])

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("summarize") == true)
        #expect(desc?.contains("text") == true)
        #expect(desc?.contains("style") == true)
    }

    @Test("recipeNotFound has a non-nil errorDescription")
    func recipeNotFound_hasDescription() {
        // Given
        let error = AIError.recipeNotFound("translate")

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("Recipe not found") == true)
        #expect(desc?.contains("translate") == true)
    }

    @Test("skillNotFound has a non-nil errorDescription")
    func skillNotFound_hasDescription() {
        // Given
        let error = AIError.skillNotFound("analyzer")

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("Skill not found") == true)
        #expect(desc?.contains("analyzer") == true)
    }

    @Test("requestBuildingFailed has a non-nil errorDescription")
    func requestBuildingFailed_hasDescription() {
        // Given
        let error = AIError.requestBuildingFailed("Missing model")

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("Invalid request") == true)
        #expect(desc?.contains("Missing model") == true)
    }

    @Test("rateLimitExceeded with retryAfter has a non-nil errorDescription")
    func rateLimitExceeded_withRetry_hasDescription() {
        // Given
        let error = AIError.rateLimitExceeded(retryAfter: 30.0)

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("Rate limit exceeded") == true)
        #expect(desc?.contains("30.0") == true)
    }

    @Test("rateLimitExceeded without retryAfter has a non-nil errorDescription")
    func rateLimitExceeded_withoutRetry_hasDescription() {
        // Given
        let error = AIError.rateLimitExceeded(retryAfter: nil)

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("Rate limit exceeded") == true)
    }

    @Test("contextLengthExceeded has a non-nil errorDescription")
    func contextLengthExceeded_hasDescription() {
        // Given
        let error = AIError.contextLengthExceeded

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("context window") == true)
    }

    @Test("invalidModel has a non-nil errorDescription")
    func invalidModel_hasDescription() {
        // Given
        let error = AIError.invalidModel("fake-model-999")

        // When
        let desc = error.errorDescription

        // Then
        #expect(desc != nil)
        #expect(desc?.contains("Invalid model") == true)
        #expect(desc?.contains("fake-model-999") == true)
    }
}
