#if canImport(FoundationModels)
import FoundationModels
#endif

/// Checks whether the on-device Foundation Models runtime is usable
/// on the current device and OS version.
///
/// Call this before creating a `FoundationModelProvider` in production code:
///
/// ```swift
/// guard FoundationModelAvailability.isAvailable else {
///     // Fall back to a remote provider
/// }
/// let provider = FoundationModelProvider()
/// ```
public enum FoundationModelAvailability {

    /// `true` when `FoundationModels` is importable on this platform *and*
    /// `SystemLanguageModel.default.isAvailable` returns `true` at runtime.
    public static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        return false
        #else
        return false
        #endif
    }
}
