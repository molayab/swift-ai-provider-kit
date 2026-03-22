import Foundation

/// Provider-agnostic async CRUD interface for conversation persistence.
///
/// `AIClient` owns a store selected at init time via ``SupportedConversationStore``.
/// Callers interact with conversations through `AIClient`'s conversation API;
/// direct store access is available for advanced use cases.
///
/// Conforming types must be `Sendable` since the store is accessed from
/// `AIClient`'s actor context.
public protocol ConversationStore: Sendable {

    // MARK: - Conversation lifecycle

    /// Creates a new, empty conversation and persists it.
    @discardableResult func createConversation(title: String, model: AIModel) async throws -> Conversation

    /// Returns the stored conversation with the given identifier, or `nil` if not found.
    ///
    /// Implementations should provide O(1) or index-backed lookup where possible.
    func conversation(byId id: UUID) async throws -> Conversation?

    /// Returns all stored conversations, ordered by creation date descending.
    func allConversations() async throws -> [Conversation]

    /// Replaces the stored conversation with the latest version.
    ///
    /// Used internally by `AIClient` after appending turns. Throws
    /// `AIError.conversationNotFound` if no matching conversation exists.
    func save(_ conversation: Conversation) async throws

    /// Permanently removes a conversation and all its turns.
    func delete(_ conversation: Conversation) async throws

    /// Marks the conversation as archived by setting `archivedAt` to the current date.
    func archive(_ conversation: Conversation) async throws
}
