import AIProviderKit
import Foundation

// MARK: - Request

struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let tools: [OpenAITool]?
    let temperature: Double?
    let maxTokens: Int
    let topP: Double?
    let stop: [String]?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, temperature, stop, stream
        case maxTokens = "max_tokens"
        case topP = "top_p"
    }
}

/// A message in the OpenAI Chat Completions conversation.
///
/// Supports all four roles: `system`, `user`, `assistant`, and `tool`.
/// The `content`, `toolCalls`, and `toolCallId` fields are role-dependent
/// and are omitted from JSON when `nil`.
struct OpenAIMessage: Encodable {
    let role: String
    let content: OpenAIContent?
    let toolCalls: [OpenAIToolCall]?
    let toolCallId: String?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

/// Message content — either a plain string or a multipart array (text + images).
enum OpenAIContent: Encodable {
    case text(String)
    case parts([OpenAIContentPart])

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .text(let string):
            var container = encoder.singleValueContainer()
            try container.encode(string)
        case .parts(let parts):
            var container = encoder.singleValueContainer()
            try container.encode(parts)
        }
    }
}

struct OpenAIContentPart: Encodable {
    let type: String
    let text: String?
    let imageUrl: OpenAIImageURL?

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }
}

struct OpenAIImageURL: Encodable {
    let url: String
}

struct OpenAIToolCall: Codable {
    let id: String
    let type: String
    let function: OpenAIFunctionCall
}

struct OpenAIFunctionCall: Codable {
    let name: String
    /// JSON-encoded string of the function arguments.
    let arguments: String
}

struct OpenAITool: Encodable {
    let type: String
    let function: OpenAIFunction
}

struct OpenAIFunction: Encodable {
    let name: String
    let description: String
    /// JSON Schema describing the function's parameters.
    let parameters: JSONSchemaWrapper
}

/// Wrapper to forward `JSONSchema` encoding through OpenAI's `parameters` key.
struct JSONSchemaWrapper: Encodable {
    let schema: AIProviderKit.JSONSchema

    init(_ schema: AIProviderKit.JSONSchema) {
        self.schema = schema
    }

    func encode(to encoder: any Encoder) throws {
        try schema.encode(to: encoder)
    }
}

// MARK: - Response

struct OpenAIChatResponse: Decodable {
    let id: String
    let model: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage
}

struct OpenAIChoice: Decodable {
    let index: Int
    let message: OpenAIResponseMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct OpenAIResponseMessage: Decodable {
    let role: String
    let content: String?
    let toolCalls: [OpenAIToolCall]?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }
}

struct OpenAIUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }
}

struct OpenAIErrorResponse: Decodable {
    let error: OpenAIAPIError

    struct OpenAIAPIError: Decodable {
        let message: String
        let type: String?
        let code: String?
    }
}

// MARK: - Model List (GET /v1/models)

struct OpenAIModelListResponse: Decodable {
    let object: String
    let data: [OpenAIModelObject]
}

struct OpenAIModelObject: Decodable {
    let id: String
    let created: Int
    let ownedBy: String

    enum CodingKeys: String, CodingKey {
        case id, created
        case ownedBy = "owned_by"
    }
}

// MARK: - Streaming

struct OpenAIChatChunk: Decodable {
    let id: String?
    let choices: [OpenAIChunkChoice]

    struct OpenAIChunkChoice: Decodable {
        let index: Int
        let delta: OpenAIDelta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }

    struct OpenAIDelta: Decodable {
        let role: String?
        let content: String?
        let toolCalls: [OpenAIToolCallDelta]?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
        }
    }

    struct OpenAIToolCallDelta: Decodable {
        let index: Int
        let id: String?
        let type: String?
        let function: OpenAIFunctionDelta?
    }

    struct OpenAIFunctionDelta: Decodable {
        let name: String?
        let arguments: String?
    }
}
