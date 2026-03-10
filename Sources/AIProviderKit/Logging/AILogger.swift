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

    public let subsystem: String
    public let category: String

    private let osLogger: os.Logger

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        self.osLogger = os.Logger(subsystem: subsystem, category: category)
    }

    // MARK: - Logging

    public func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        forward(AILogEntry(level: .info, subsystem: subsystem, category: category, message: message))
    }

    public func warning(_ message: String) {
        osLogger.warning("\(message, privacy: .public)")
        forward(AILogEntry(level: .warning, subsystem: subsystem, category: category, message: message))
    }

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
