import AIProviderKit
@testable import ClaudeProvider
import Testing

@Suite("APIKeyAuthorization")
struct APIKeyAuthorizationTests {

    @Test("valid key returns headers with x-api-key")
    func validKey_returnsCorrectHeaders() async throws {
        // Given
        let auth = APIKeyAuthorization(apiKey: "sk-ant-test-12345")

        // When
        let headers = try await auth.authorizationHeaders()

        // Then
        #expect(headers == ["x-api-key": "sk-ant-test-12345"])
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
