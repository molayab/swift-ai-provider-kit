import AIProviderKit
import Foundation
import SwiftData

/// The file extension used for portable conversation bundles.
public let conversationFileExtension = "chat"

// MARK: - Import / Export

extension SwiftDataConversationStore {

    // MARK: - Export

    /// Exports a single conversation as JSON data suitable for writing to a `.chat` file.
    ///
    /// - Parameter id: The conversation identifier.
    /// - Returns: JSON-encoded ``Conversation`` data.
    public func exportConversation(_ id: UUID) async throws -> Data {
        guard let conversation = try await conversation(byId: id) else {
            throw AIError.conversationNotFound(id.uuidString)
        }
        return try Self.encoder.encode(conversation)
    }

    /// Exports a single conversation directly to a `.chat` file at the given URL.
    ///
    /// - Parameters:
    ///   - id: The conversation identifier.
    ///   - url: The file URL to write to. Should use the `.chat` extension.
    @concurrent
    nonisolated public func exportConversation(_ id: UUID, to url: URL) async throws {
        let data = try await exportConversation(id)
        try data.write(to: url, options: .atomic)
    }

    /// Exports all conversations as a JSON array.
    public func exportAll() async throws -> Data {
        let conversations = try await allConversations()
        return try Self.encoder.encode(conversations)
    }

    // MARK: - Import

    /// Imports a conversation from JSON data (e.g. the contents of a `.chat` file).
    ///
    /// If a conversation with the same identifier already exists, it is overwritten.
    ///
    /// - Parameter data: JSON-encoded ``Conversation``.
    /// - Returns: The imported conversation.
    @discardableResult public func importConversation(from data: Data) async throws -> Conversation {
        let conversation: Conversation
        do {
            conversation = try Self.decoder.decode(Conversation.self, from: data)
        } catch {
            throw AIError.decodingFailed(underlying: error)
        }
        try await upsert(conversation)
        return conversation
    }

    /// Imports a conversation from a `.chat` file at the given URL.
    ///
    /// - Parameter url: The file URL to read from.
    /// - Returns: The imported conversation.
    @concurrent
    @discardableResult nonisolated public func importConversation(from url: URL) async throws -> Conversation {
        let data = try Data(contentsOf: url)
        return try await importConversation(from: data)
    }

    /// Imports multiple conversations from a JSON array.
    ///
    /// - Parameter data: JSON-encoded `[Conversation]`.
    /// - Returns: All imported conversations.
    @discardableResult public func importConversations(from data: Data) async throws -> [Conversation] {
        let conversations: [Conversation]
        do {
            conversations = try Self.decoder.decode([Conversation].self, from: data)
        } catch {
            throw AIError.decodingFailed(underlying: error)
        }
        for conv in conversations {
            try await upsert(conv)
        }
        return conversations
    }

    // MARK: - Private

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Inserts or replaces a conversation in the store.
    private func upsert(_ conversation: Conversation) async throws {
        let id = conversation.id
        let descriptor = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
        }
        let record = try ConversationRecord.from(conversation)
        modelContext.insert(record)
        try modelContext.save()
    }
}
