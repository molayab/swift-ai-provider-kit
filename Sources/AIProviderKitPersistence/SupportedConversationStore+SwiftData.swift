import AIProviderKit
import SwiftData

extension SupportedConversationStore {

    /// SwiftData-backed persistence. Conversations are stored in the provided
    /// ``ModelContainer`` and survive across app launches.
    ///
    /// ```swift
    /// import AIProviderKitPersistence
    ///
    /// let container = try ModelContainer(
    ///     for: ConversationRecord.self, ConversationTurnRecord.self
    /// )
    /// let client = AIClient(
    ///     provider: claude,
    ///     store: .swiftData(container: container)
    /// )
    /// ```
    public static func swiftData(container: ModelContainer) -> SupportedConversationStore {
        .custom(SwiftDataConversationStore(modelContainer: container))
    }
}
