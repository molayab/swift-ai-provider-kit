/// Selects and configures the conversation persistence backend at `AIClient` init time.
///
/// Swapping backends is a one-line change:
///
/// ```swift
/// let client = AIClient(provider: claude, store: .ephemeralMemory)
/// ```
///
/// Additional backends (`.fileSystem`, `.database`) will be added in `AIProviderKitPersistenceFS`
/// and `AIProviderKitPersistenceDB` respectively (milestones 0.4.1 and 0.4.2).
public enum SupportedConversationStore: Sendable {
    /// Zero-dependency in-memory store. Conversations survive the `AIClient` lifetime
    /// but are discarded when the process exits.
    case ephemeralMemory

    // MARK: - Internal factory

    func makeStore() -> any ConversationStore {
        switch self {
        case .ephemeralMemory:
            return EphemeralMemoryConversationStore()
        }
    }
}
