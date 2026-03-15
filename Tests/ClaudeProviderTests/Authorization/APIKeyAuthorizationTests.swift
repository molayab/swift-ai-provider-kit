import AIProviderKit
@testable import ClaudeProvider
import Testing

@Suite("APIKeyAuthorization")
struct APIKeyAuthorizationTests {

    @Test("valid key returns headers with x-api-key")
    func validKey_returnsCorrectHeaders() async throws {
        // Given
        let auth = APIKeyAuthorization(apiKey: "test-api-key")

        // When
        let headers = try await auth.authorizationHeaders()

        // Then
        #expect(headers == ["x-api-key": "test-api-key"])
    }

    @Test("empty key throws authorizationFailed")
    func emptyKey_throwsAuthorizationFailed() async {
        // Given
        let auth = APIKeyAuthorization(apiKey: "")

        // When / Then
        await #expect(throws: AIError.self) {
            try await auth.authorizationHeaders()
        }
    }
}
