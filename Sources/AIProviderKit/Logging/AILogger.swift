import os

/// A structured logger backed by `os.Logger`.
///
/// Writes to the system log (visible in Console.app) and optionally
/// forwards entries to `AILogStore.shared` for in-app display via `AILogView`.
///
/// ```swift
/// let logger = AILogger(subsystem: "com.myapp", category: "network")
/// logger.info("Request started")
/// logger.warning("Retrying after rate limit")
/// logger.error("Decoding failed: \(error)")
/// ```
public struct AILogger: Sendable {

    /// The reverse-DNS subsystem identifier forwarded to `os.Logger` (e.g. `"com.myapp"`).
    public let subsystem: String
    /// The category forwarded to `os.Logger`, used for filtering in Console.app.
    public let category: String

    private let osLogger: os.Logger

    /// Creates a logger that writes to the system log under the given subsystem and category.
    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        self.osLogger = os.Logger(subsystem: subsystem, category: category)
    }

    // MARK: - Logging

    /// Writes an informational message to `os.Logger` and forwards it to ``AILogStore/shared``.
    public func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        forward(AILogEntry(level: .info, subsystem: subsystem, category: category, message: message))
    }

    /// Writes a warning message to `os.Logger` and forwards it to ``AILogStore/shared``.
    public func warning(_ message: String) {
        osLogger.warning("\(message, privacy: .public)")
        forward(AILogEntry(level: .warning, subsystem: subsystem, category: category, message: message))
    }

    /// Writes an error message to `os.Logger` and forwards it to ``AILogStore/shared``.
    public func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        forward(AILogEntry(level: .error, subsystem: subsystem, category: category, message: message))
    }

    // MARK: - Private

    private func forward(_ entry: AILogEntry) {
        Task { @MainActor in
            AILogStore.shared?.append(entry)
        }
    }
}
