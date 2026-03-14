@testable import AIProviderKit
import Foundation
import Testing

@Suite("TokenUsage")
struct TokenUsageTests {

    @Test("totalTokens equals sum of input and output tokens")
    func totalTokens_sumsInputAndOutput() {
        // Given
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)

        // When
        let total = usage.totalTokens

        // Then
        #expect(total == 150)
    }

    @Test("totalTokens is zero when both are zero")
    func totalTokens_zeroTokens_returnsZero() {
        // Given
        let usage = TokenUsage(inputTokens: 0, outputTokens: 0)

        // When
        let total = usage.totalTokens

        // Then
        #expect(total == 0)
    }

    @Test("Equatable conformance works for identical values")
    func equatable_identicalValues_areEqual() {
        // Given
        let lhs = TokenUsage(inputTokens: 10, outputTokens: 5)
        let rhs = TokenUsage(inputTokens: 10, outputTokens: 5)

        // When / Then
        #expect(lhs == rhs)
    }

    @Test("Equatable conformance works for different values")
    func equatable_differentValues_areNotEqual() {
        // Given
        let lhs = TokenUsage(inputTokens: 10, outputTokens: 5)
        let rhs = TokenUsage(inputTokens: 10, outputTokens: 6)

        // When / Then
        #expect(lhs != rhs)
    }

    @Test("Codable round-trip preserves values")
    func codableRoundTrip_preservesValues() throws {
        // Given
        let original = TokenUsage(inputTokens: 42, outputTokens: 18)

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: data)

        // Then
        #expect(decoded == original)
    }
}
