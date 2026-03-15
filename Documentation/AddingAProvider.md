# Adding a New Provider

This guide walks through implementing a new `AIProvider` without touching any existing code — the Open/Closed Principle in practice.

> **Reference implementation:** `OpenAIProvider` (shipped in 0.3.0) is a complete example of every step below. Read its source alongside this guide.

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

Your test target can import `AIProviderKit` and use `MockData` for baseline fixtures. Inject `MockHTTPClient` via the internal `init` to avoid any network calls.

```mermaid
flowchart LR
    Request["AIRequest"] --> Mapper["XRequestMapper"]
    Mapper --> HTTP["URLSessionHTTPClient"]
    HTTP --> API["api.provider.com"]
    API --> HTTP2["URLSessionHTTPClient"]
    HTTP2 --> RMapper["XResponseMapper"]
    RMapper --> Response["AIResponse"]
```

### 7. Centralise constants (recommended)

Create an internal `XProviderConstants` enum to hold endpoint URLs, model-family prefixes, and any other string literals. This makes it trivial to add support for new model families without touching the provider or mapper code. See `OpenAIConstants` for the established pattern.

### 8. Optionally conform to `ModelDiscoveryProvider`

If the backend exposes a model-listing endpoint, conform to `ModelDiscoveryProvider` from `AIProviderKit`:

```swift
public func listModels() async throws(AIError) -> [AIModelInfo] {
    // GET <modelsEndpoint>, decode, filter, map to [AIModelInfo]
}
```

`OpenAIProvider` ships a complete implementation. `ClaudeProvider` will add this in milestone 0.3.1.
