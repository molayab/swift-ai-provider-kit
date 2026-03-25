import AIProviderKit
import Foundation
import SwiftData

/// SwiftData model that persists a single ``ConversationTurn``.
///
/// The ``Message`` payload is stored as JSON-encoded `Data` in ``messageData``
/// to avoid modelling every ``ContentBlock`` variant as SwiftData entities.
@Model
public final class ConversationTurnRecord {

    @Attribute(.unique)
    public var id: UUID

    /// JSON-encoded ``Message`` payload.
    public var messageData: Data
    public var createdAt: Date
    public var inputTokens: Int?
    public var outputTokens: Int?

    public var conversation: ConversationRecord?

    public init(
        id: UUID,
        messageData: Data,
        createdAt: Date,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        conversation: ConversationRecord? = nil
    ) {
        self.id = id
        self.messageData = messageData
        self.createdAt = createdAt
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.conversation = conversation
    }
}

// MARK: - Mapping

extension ConversationTurnRecord {

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Converts this record into a ``ConversationTurn`` value type.
    ///
    /// Returns `nil` if the stored ``messageData`` cannot be decoded.
    func toConversationTurn() -> ConversationTurn? {
        guard let message = try? Self.decoder.decode(Message.self, from: messageData) else {
            return nil
        }
        let usage: TokenUsage? = if let input = inputTokens, let output = outputTokens {
            TokenUsage(inputTokens: input, outputTokens: output)
        } else {
            nil
        }
        return ConversationTurn(
            id: id,
            message: message,
            createdAt: createdAt,
            tokenUsage: usage
        )
    }

    /// Creates a new record from a ``ConversationTurn`` value type.
    static func from(
        _ turn: ConversationTurn,
        conversation: ConversationRecord? = nil
    ) throws -> ConversationTurnRecord {
        let data: Data
        do {
            data = try encoder.encode(turn.message)
        } catch {
            throw AIError.encodingFailed(underlying: error)
        }
        return ConversationTurnRecord(
            id: turn.id,
            messageData: data,
            createdAt: turn.createdAt,
            inputTokens: turn.tokenUsage?.inputTokens,
            outputTokens: turn.tokenUsage?.outputTokens,
            conversation: conversation
        )
    }
}
