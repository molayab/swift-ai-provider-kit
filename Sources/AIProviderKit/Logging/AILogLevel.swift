/// Severity levels for `AILogger`.
public enum AILogLevel: String, Sendable, Comparable, CaseIterable {
    case info    = "INFO"
    case warning = "WARNING"
    case error   = "ERROR"

    // MARK: - Comparable

    private var order: Int {
        switch self {
        case .info:    return 0
        case .warning: return 1
        case .error:   return 2
        }
    }

    public static func < (lhs: AILogLevel, rhs: AILogLevel) -> Bool {
        lhs.order < rhs.order
    }
}
