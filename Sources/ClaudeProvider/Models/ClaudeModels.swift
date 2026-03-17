import AIProviderKit
import Foundation

// MARK: - Request

struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [ClaudeMessage]
    let tools: [ClaudeTool]?
    let temperature: Double?
    let topP: Double?
    let stopSequences: [String]?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, system, messages, tools, temperature, stream
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case stopSequences = "stop_sequences"
    }
}

struct ClaudeMessage: Encodable {
    let role: String
    let content: [ClaudeContentBlock]
}

struct ClaudeContentBlock: Codable {
    let type: String
    let text: String?
    let source: ClaudeImageSource?
    let id: String?
    let name: String?
    let input: JSONValue?
    let toolUseId: String?
    let content: [ClaudeContentBlock]?
    // swiftlint:disable:next discouraged_optional_boolean
    let isError: Bool?

    enum CodingKeys: String, CodingKey {
        case type, text, source, id, name, input, content
        case toolUseId = "tool_use_id"
        case isError = "is_error"
    }
}

struct ClaudeImageSource: Codable {
    let type: String
    let mediaType: String?
    let data: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case type, data, url
        case mediaType = "media_type"
    }
}

struct ClaudeTool: Encodable {
    let name: String
    let description: String
    let inputSchema: JSONSchema

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

// MARK: - Response

struct ClaudeResponse: Decodable {
    let id: String
    let model: String
    let content: [ClaudeContentBlock]
    let stopReason: String?
    let usage: ClaudeUsage

    enum CodingKeys: String, CodingKey {
        case id, model, content, usage
        case stopReason = "stop_reason"
    }
}

struct ClaudeUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Model List (GET /v1/models)

struct ClaudeModelListResponse: Decodable {
    let data: [ClaudeModelObject]
    let hasMore: Bool
    let firstId: String?
    let lastId: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case firstId = "first_id"
        case lastId = "last_id"
    }
}

struct ClaudeModelObject: Decodable {
    let id: String
    let displayName: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case createdAt = "created_at"
    }
}

// MARK: - Error

struct ClaudeErrorResponse: Decodable {
    let type: String
    let error: Detail

    struct Detail: Decodable {
        let type: String
        let message: String
    }
}

// MARK: - Streaming

struct ClaudeStreamEvent: Decodable {
    let type: String
    let index: Int?
    let delta: ClaudeStreamDelta?
    /// Present on `message_start` events — carries `id`, `model`, and initial token usage.
    let message: ClaudeStreamMessage?
    /// Present on `content_block_start` events — identifies the block type plus `id`/`name` for tool_use blocks.
    let contentBlock: ClaudeStreamContentBlock?
    /// Present on `message_delta` events — carries final output token count.
    let usage: ClaudeStreamDeltaUsage?
    /// Present on `error` events — carries the Anthropic error type and message.
    let error: ClaudeStreamErrorPayload?

    struct ClaudeStreamDelta: Decodable {
        let type: String?
        let text: String?
        let stopReason: String?
        /// Incremental tool-call input JSON fragment, present when `type == "input_json_delta"`.
        let partialJson: String?

        enum CodingKeys: String, CodingKey {
            case type, text
            case stopReason = "stop_reason"
            case partialJson = "partial_json"
        }
    }

    /// Payload of a `message_start` SSE event.
    struct ClaudeStreamMessage: Decodable {
        let id: String?
        let model: String?
        let usage: ClaudeUsage?
    }

    /// Payload of a `content_block_start` SSE event.
    struct ClaudeStreamContentBlock: Decodable {
        let type: String
        let id: String?
        let name: String?
    }

    /// Usage fragment carried by `message_delta` events (output tokens only).
    struct ClaudeStreamDeltaUsage: Decodable {
        let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case outputTokens = "output_tokens"
        }
    }

    /// Payload of an `error` SSE event — carries the Anthropic error type and human-readable message.
    struct ClaudeStreamErrorPayload: Decodable {
        let type: String
        let message: String
    }

    enum CodingKeys: String, CodingKey {
        case type, index, delta, message, usage, error
        case contentBlock = "content_block"
    }
}
