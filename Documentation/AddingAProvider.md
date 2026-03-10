# Adding a New Provider

This guide walks through implementing a new `AIProvider` (e.g. OpenAI) without touching any existing code — the Open/Closed Principle in practice.

## Steps

### 1. Create the target

Add a new library target in `Package.swift`:

```swift
.library(name: "OpenAIProvider", targets: ["OpenAIProvider"]),
// ...
.target(name: "OpenAIProvider", dependencies: ["AIProviderKit"], path: "Sources/OpenAIProvider"),
```

### 2. Implement `AIProvider`

```swift
import AIProviderKit

public final class OpenAIProvider: StreamableProvider {

    public let identifier = "openai"
    public let capabilities: Set<AICapability> = [.text, .vision, .tools, .streaming, .systemPrompt]

    private let authorization: any AuthorizationProvider
    private let httpClient: any HTTPClient    // your internal protocol

    public init(authorization: any AuthorizationProvider) { ... }

    public func send(_ request: AIRequest) async throws -> AIResponse {
        // Map AIRequest -> OpenAI request body
        // POST to https://api.openai.com/v1/chat/completions
        // Map OpenAI response -> AIResponse
    }

    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        // Same flow with stream: true
    }
}
```

### 3. Expose model constants

```swift
public extension AIModel {
    static let gpt4o     = AIModel("gpt-4o")
    static let gpt4oMini = AIModel("gpt-4o-mini")
}
```

### 4. Add `AuthorizationProvider` (if needed)

OpenAI uses `Authorization: Bearer <key>`, so you can either implement a new type or reuse a generic `BearerAuthorization`:

```swift
public struct BearerAuthorization: AuthorizationProvider {
    private let token: String
    public init(token: String) { self.token = token }
    public func authorizationHeaders() async throws -> [String: String] {
        ["Authorization": "Bearer \(token)"]
    }
}
```

### 5. Map content blocks

Both Claude and OpenAI use similar message structures. The key differences are:

| Concept        | Claude                        | OpenAI                             |
|----------------|-------------------------------|------------------------------------|
| Tool call      | `tool_use` content block      | `tool_calls` array in message      |
| Tool result    | `tool_result` content block   | `tool` role message                |
| System prompt  | Top-level `system` field      | `{"role": "system", "content": …}` |
| Image input    | `image` content block         | Inline image in `content` array    |

### 6. Test with the shared test helpers

Your test target can import `AIProviderKit` and use `MockData` for baseline fixtures.

```mermaid
flowchart LR
    Request["AIRequest"] --> Mapper["OpenAIRequestMapper"]
    Mapper --> HTTP["URLSessionHTTPClient"]
    HTTP --> API["api.openai.com"]
    API --> HTTP2["URLSessionHTTPClient"]
    HTTP2 --> RMapper["OpenAIResponseMapper"]
    RMapper --> Response["AIResponse"]
```
