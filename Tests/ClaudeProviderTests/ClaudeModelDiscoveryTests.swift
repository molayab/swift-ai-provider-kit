import AIProviderKit
import AIProviderKitNetworking
@testable import ClaudeProvider
import Foundation
import Testing

extension Tag {
    @Tag static var networking: Self
}

@Suite("ClaudeProvider model discovery")
struct ClaudeModelDiscoveryTests {

    private func makeProvider(httpClient: MockHTTPClient) -> ClaudeProvider {
        ClaudeProvider(
            authorization: MockAPIKeyAuthorization(),
            httpClient: httpClient
        )
    }

    @Test("listModels returns mapped models from single-page response", .tags(.networking))
    func listModels_singlePage_returnsMappedModels() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: ClaudeModelListFixture.singlePageJSON
        )
        let provider = makeProvider(httpClient: httpClient)

        // When
        let models = try await provider.listModels()

        // Then
        #expect(models.count == 3)
        #expect(models[0].model.identifier == "claude-opus-4-6")
        #expect(models[0].displayName == "Claude Opus 4.6")
        #expect(models[1].model.identifier == "claude-sonnet-4-6")
        #expect(models[2].model.identifier == "claude-haiku-4-5-20251001")
        #expect(models[0].createdAt != nil)
    }

    @Test("listModels follows pagination until has_more is false", .tags(.networking))
    func listModels_multiPage_collectsAllModels() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponseQueue = [
            HTTPResponse(statusCode: 200, body: ClaudeModelListFixture.pageOneJSON),
            HTTPResponse(statusCode: 200, body: ClaudeModelListFixture.pageTwoJSON)
        ]
        let provider = makeProvider(httpClient: httpClient)

        // When
        let models = try await provider.listModels()

        // Then — both pages combined
        #expect(models.count == 4)
        #expect(models[0].model.identifier == "claude-opus-4-6")
        #expect(models[3].model.identifier == "claude-haiku-4-5")

        // Second request should carry after_id cursor from page one
        #expect(httpClient.receivedRequests.count == 2)
        let secondURL = httpClient.receivedRequests[1].url.absoluteString
        #expect(secondURL.contains("after_id=model-cursor-id"))
    }

    @Test("listModels throws networkError on URLError", .tags(.networking))
    func listModels_throwsNetworkError_onURLError() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedError = URLError(.notConnectedToInternet)
        let provider = makeProvider(httpClient: httpClient)

        // When / Then
        do {
            _ = try await provider.listModels()
            Issue.record("Expected AIError.networkError to be thrown")
        } catch {
            guard case .networkError = error else {
                Issue.record("Wrong AIError case thrown: \(error)")
                return
            }
        }
    }

    @Test("listModels throws invalidResponse on HTTP 401", .tags(.networking))
    func listModels_throwsInvalidResponse_on401() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(statusCode: 401, body: Data("Unauthorized".utf8))
        let provider = makeProvider(httpClient: httpClient)

        // When / Then
        do {
            _ = try await provider.listModels()
            Issue.record("Expected AIError.invalidResponse to be thrown")
        } catch {
            guard case .invalidResponse = error else {
                Issue.record("Wrong AIError case thrown: \(error)")
                return
            }
        }
    }

    @Test("listModels throws decodingFailed on malformed JSON", .tags(.networking))
    func listModels_throwsDecodingFailed_onMalformedJSON() async throws {
        // Given
        let httpClient = MockHTTPClient()
        httpClient.stubbedResponse = HTTPResponse(
            statusCode: 200,
            body: Data("not json".utf8)
        )
        let provider = makeProvider(httpClient: httpClient)

        // When / Then
        do {
            _ = try await provider.listModels()
            Issue.record("Expected AIError.decodingFailed to be thrown")
        } catch {
            guard case .decodingFailed = error else {
                Issue.record("Wrong AIError case thrown: \(error)")
                return
            }
        }
    }
}

// MARK: - Test Helpers

private struct MockAPIKeyAuthorization: AuthorizationProvider {
    func authorizationHeaders() async throws(AIError) -> [String: String] {
        ["x-api-key": "test-key"]
    }
}

// MARK: - Fixtures

private enum ClaudeModelListFixture {

    static let singlePageJSON = Data("""
    {
        "data": [
            {"id": "claude-opus-4-6", "display_name": "Claude Opus 4.6", "created_at": "2025-08-01T00:00:00Z"},
            {"id": "claude-sonnet-4-6", "display_name": "Claude Sonnet 4.6", "created_at": "2025-07-01T00:00:00Z"},
            {"id": "claude-haiku-4-5-20251001", "display_name": "Claude Haiku 4.5", "created_at": "2025-10-01T00:00:00Z"}
        ],
        "has_more": false,
        "first_id": "claude-opus-4-6",
        "last_id": "claude-haiku-4-5-20251001"
    }
    """.utf8)

    static let pageOneJSON = Data("""
    {
        "data": [
            {"id": "claude-opus-4-6", "display_name": "Claude Opus 4.6", "created_at": "2025-08-01T00:00:00Z"},
            {"id": "claude-sonnet-4-6", "display_name": "Claude Sonnet 4.6", "created_at": "2025-07-01T00:00:00Z"}
        ],
        "has_more": true,
        "first_id": "claude-opus-4-6",
        "last_id": "model-cursor-id"
    }
    """.utf8)

    static let pageTwoJSON = Data("""
    {
        "data": [
            {"id": "claude-haiku-4-5-20251001", "display_name": "Claude Haiku 4.5", "created_at": "2025-10-01T00:00:00Z"},
            {"id": "claude-haiku-4-5", "display_name": "Claude Haiku 4.5 Preview", "created_at": "2025-06-01T00:00:00Z"}
        ],
        "has_more": false,
        "first_id": "claude-haiku-4-5-20251001",
        "last_id": "claude-haiku-4-5"
    }
    """.utf8)
}
