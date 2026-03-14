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
    let delta: ClaudeStreamDelta?
    let index: Int?

    struct ClaudeStreamDelta: Decodable {
        let type: String?
        let text: String?
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case type, text
            case stopReason = "stop_reason"
        }
    }
}
