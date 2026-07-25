@testable import AppleIntelligenceProvider
import Testing

@Suite("AppleIntelligenceAvailability")
struct AppleIntelligenceAvailabilityTests {

    // `isAvailable`/`unavailableReason` both read the live `SystemLanguageModel` singleton, so
    // there's no seam to mock the actual availability state in a unit test — this only asserts
    // the two stay consistent with each other, on whatever device/OS runs the suite.

    @Test("isAvailable is true exactly when unavailableReason is nil")
    func isAvailable_matchesUnavailableReason() {
        // When
        let isAvailable = AppleIntelligenceAvailability.isAvailable
        let reason = AppleIntelligenceAvailability.unavailableReason

        // Then
        #expect(isAvailable == (reason == nil))
    }
}
