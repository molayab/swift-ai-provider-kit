import AIProviderKit
@testable import OpenAIProvider
import Testing

@Suite("BearerAuthorization")
struct BearerAuthorizationTests {

    @Test("authorizationHeaders returns Bearer token header")
    func authorizationHeaders_returnsBearerToken() async throws {
        // Given
        let sut = BearerAuthorization(apiKey: "test-api-key")

        // When
        let headers = try await sut.authorizationHeaders()

        // Then
        #expect(headers["Authorization"] == "Bearer test-api-key")
    }

    @Test("authorizationHeaders throws authorizationFailed for empty key")
    func authorizationHeaders_throwsForEmptyKey() async {
        // Given
        let sut = BearerAuthorization(apiKey: "")

        // When / Then
        await #expect(throws: AIError.self) {
            try await sut.authorizationHeaders()
        }
    }

    @Test("header key is Authorization with capital A")
    func headerKey_isAuthorizationWithCapitalA() async throws {
        // Given
        let sut = BearerAuthorization(apiKey: "test-api-key")

        // When
        let headers = try await sut.authorizationHeaders()

        // Then
        #expect(headers.keys.contains("Authorization"))
        #expect(headers.count == 1)
    }
}
