import Observation

/// An observable in-memory log sink for use with `AILogView`.
///
/// Set `AILogStore.shared` once at app startup to enable UI log capture.
/// If `shared` is `nil`, `AILogger` writes only to the system log (OSLog).
///
/// ```swift
/// // AppDelegate / @main
/// AILogStore.shared = AILogStore()
/// ```
@Observable
@MainActor
public final class AILogStore {

    // MARK: - Shared sink

    /// The optional global sink. Set this to start capturing log entries for the UI.
    public static var shared: AILogStore?

    // MARK: - State

    /// All captured log entries, ordered from oldest to newest.
    public private(set) var entries: [AILogEntry] = []

    /// Maximum number of entries kept in memory. Older entries are evicted first.
    /// Default: 1 000.
    public var maximumEntries: Int = 1_000

    // MARK: - Init

    public init() {}

    // MARK: - Internal

    func append(_ entry: AILogEntry) {
        entries.append(entry)
        if entries.count > maximumEntries {
            entries.removeFirst(entries.count - maximumEntries)
        }
    }

    public func clear() {
        entries.removeAll()
    }
}
