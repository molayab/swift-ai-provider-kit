#if canImport(FoundationModels)
import FoundationModels
#endif

/// Checks whether the on-device Foundation Models runtime is usable
/// on the current device and OS version.
///
/// Call this before creating an `AppleIntelligenceProvider` in production code:
///
/// ```swift
/// guard AppleIntelligenceAvailability.isAvailable else {
///     // Fall back to a remote provider
/// }
/// let provider = AppleIntelligenceProvider()
/// ```
public enum AppleIntelligenceAvailability {

    /// Why the on-device runtime can't be used right now — mirrors
    /// `SystemLanguageModel.Availability.UnavailableReason` without exposing `FoundationModels`
    /// itself to callers, so consuming apps never need their own `@available`/`canImport` gating
    /// just to word a helpful message.
    public enum UnavailableReason: Sendable, Equatable {
        /// The device's hardware doesn't support Apple Intelligence.
        case deviceNotEligible
        /// The device could run Apple Intelligence, but the user hasn't turned it on.
        case appleIntelligenceNotEnabled
        /// Apple Intelligence is enabled but the on-device model assets aren't ready yet.
        case modelNotReady
        /// The current OS/platform doesn't ship `FoundationModels` at all (below iOS/macOS 26).
        case unsupportedOS
    }

    /// `true` when `FoundationModels` is importable on this platform *and*
    /// `SystemLanguageModel.default.isAvailable` returns `true` at runtime.
    public static var isAvailable: Bool {
        unavailableReason == nil
    }

    /// The specific reason the on-device runtime is unusable, or `nil` when it's available.
    ///
    /// ```swift
    /// if let reason = AppleIntelligenceAvailability.unavailableReason {
    ///     // Word a message specific to `reason` instead of a generic "not available".
    /// }
    /// ```
    public static var unavailableReason: UnavailableReason? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return .deviceNotEligible
                case .appleIntelligenceNotEnabled:
                    return .appleIntelligenceNotEnabled
                case .modelNotReady:
                    return .modelNotReady
                @unknown default:
                    return .modelNotReady
                }
            }
        }
        return .unsupportedOS
        #else
        return .unsupportedOS
        #endif
    }
}
