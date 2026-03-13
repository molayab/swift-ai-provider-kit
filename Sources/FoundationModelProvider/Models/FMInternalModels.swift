import Foundation
import AIProviderKit

// MARK: - Internal FM Request

/// Internal representation of a mapped Foundation Models request.
struct FMRequest: Sendable {
    let systemPrompt: String?
    let messages: [FMMessage]
    let tools: [FMToolDefinition]
    let maxTokens: Int
    let temperature: Double?
}

// MARK: - Internal FM Message

struct FMMessage: Sendable {
    let role: String
    let content: String
}

// MARK: - Internal FM Tool Definition

struct FMToolDefinition: Sendable {
    let name: String
    let description: String
    let parametersSchemaJSON: String
    /// The original handler, retained so `LiveFMSession` can execute the tool locally.
    let handler: @Sendable (JSONValue) async throws -> JSONValue
}

// MARK: - Internal FM Response

struct FMResponse: Sendable {
    let content: String
    let toolCalls: [FMToolCall]
    let stopReason: FMStopReason
}

// MARK: - Internal FM Tool Call

struct FMToolCall: Sendable {
    let id: String
    let name: String
    let argumentsJSON: String
}

// MARK: - Internal FM Stop Reason

enum FMStopReason: String, Sendable {
    case endTurn   = "end_turn"
    case maxTokens = "max_tokens"
    case toolUse   = "tool_use"
}

// MARK: - Internal FM Stream Delta

struct FMStreamDelta: Sendable {
    let text: String
}
