/// Selects and configures the conversation persistence backend at `AIClient` init time.
///
/// Swapping backends is a one-line change:
///
/// ```swift
/// let client = AIClient(provider: claude, store: .ephemeralMemory)
/// ```
///
/// Import `AIProviderKitPersistence` to unlock the `.swiftData(container:)` convenience
/// factory (milestone 0.4.1).
public enum SupportedConversationStore: Sendable {
    /// Zero-dependency in-memory store. Conversations are kept for the lifetime of the
    /// owning `AIClient` instance and are not written to disk.
    case ephemeralMemory

    /// A pre-built store instance. Used by backend modules
    /// (e.g. `AIProviderKitPersistence`) to inject their concrete types without
    /// introducing a circular dependency on the core module.
    case custom(any ConversationStore)

    // MARK: - Internal factory

    func makeStore() -> any ConversationStore {
        switch self {
        case .ephemeralMemory:
            return EphemeralMemoryConversationStore()
        case .custom(let store):
            return store
        }
    }
}
