import Testing
@testable import AIProviderKit

@Suite("AILogLevel")
struct AILogLevelTests {

    // MARK: - Comparable

    @Test("info is less than warning")
    func comparable_infoLessThanWarning() {
        // Given
        let info = AILogLevel.info
        let warning = AILogLevel.warning

        // When / Then
        #expect(info < warning)
    }

    @Test("warning is less than error")
    func comparable_warningLessThanError() {
        // Given
        let warning = AILogLevel.warning
        let error = AILogLevel.error

        // When / Then
        #expect(warning < error)
    }

    @Test("info is less than error")
    func comparable_infoLessThanError() {
        // Given
        let info = AILogLevel.info
        let error = AILogLevel.error

        // When / Then
        #expect(info < error)
    }

    @Test("error is not less than info")
    func comparable_errorNotLessThanInfo() {
        // Given
        let error = AILogLevel.error
        let info = AILogLevel.info

        // When / Then
        #expect(!(error < info))
    }

    @Test("same level is not less than itself")
    func comparable_sameLevelNotLessThanItself() {
        // Given
        let level = AILogLevel.warning

        // When / Then
        #expect(!(level < level))
    }

    // MARK: - CaseIterable

    @Test("CaseIterable has exactly 3 cases")
    func caseIterable_hasThreeCases() {
        // Given / When
        let allCases = AILogLevel.allCases

        // Then
        #expect(allCases.count == 3)
    }

    @Test("CaseIterable contains info, warning, error")
    func caseIterable_containsAllExpectedCases() {
        // Given / When
        let allCases = AILogLevel.allCases

        // Then
        #expect(allCases.contains(.info))
        #expect(allCases.contains(.warning))
        #expect(allCases.contains(.error))
    }

    // MARK: - Raw Values

    @Test("info rawValue is INFO")
    func rawValue_info_isINFO() {
        // Given / When / Then
        #expect(AILogLevel.info.rawValue == "INFO")
    }

    @Test("warning rawValue is WARNING")
    func rawValue_warning_isWARNING() {
        // Given / When / Then
        #expect(AILogLevel.warning.rawValue == "WARNING")
    }

    @Test("error rawValue is ERROR")
    func rawValue_error_isERROR() {
        // Given / When / Then
        #expect(AILogLevel.error.rawValue == "ERROR")
    }
}
