import Foundation

/// A single captured log event, storable and displayable in `AILogView`.
public struct AILogEntry: Sendable, Identifiable {

    public let id: UUID
    public let level: AILogLevel
    public let subsystem: String
    public let category: String
    public let message: String
    public let timestamp: Date

    public init(
        level: AILogLevel,
        subsystem: String,
        category: String,
        message: String,
        timestamp: Date = .now
    ) {
        self.id = UUID()
        self.level = level
        self.subsystem = subsystem
        self.category = category
        self.message = message
        self.timestamp = timestamp
    }
}
