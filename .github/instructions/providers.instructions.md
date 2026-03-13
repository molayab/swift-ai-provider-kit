---
applyTo: "Sources/{ClaudeProvider,AppleIntelligenceProvider,OpenAIProvider}/**/*.swift"
---

# Provider Implementation Rules

## Conformance

- Providers conform to `AIProvider` for request/response only.
- Providers conform to `AIStreamableProvider` (which extends `AIProvider`) when SSE streaming is supported.
- No changes to `AIClient`, `AIProviderKit` core types, or any other provider are needed when adding a new provider.

## Mapper Pattern

- All request translation belongs in `XRequestMapper`. The provider class must not contain mapping logic.
- All response translation belongs in `XResponseMapper`. This includes SSE event parsing for streaming providers.
- Mapper types are `struct` or `enum` with static/instance pure functions — no stored state.

## ContentBlock

- `ContentBlock` (`.text`, `.image`, `.toolUse`, `.toolResult`) is the only content type exchanged with `AIProviderKit`.
- Provider-specific content types (e.g., `ClaudeContentBlock`) are internal implementation details and must not appear in any public API.

## JSONValue

- Tool inputs and outputs use `JSONValue` exclusively. Flag `Any`, `[String: Any]`, `Encodable` without a concrete type, or `AnyCodable`.

## HTTP Layer

- All HTTP calls go through the `HTTPClient` protocol (`send(_:)` / `stream(_:)`).
- The production implementation is `URLSessionHTTPClient`. Tests inject `MockHTTPClient`.
- Never call `URLSession` directly inside a provider or mapper.

## Authorization

- API keys and auth headers are provided via `AuthorizationProvider`. Never hardcode credentials.
- The standard implementation is `APIKeyAuthorization`.

## AIModel Constants

- Extend `AIModel` with `static let` constants for provider-specific models (e.g., `.claudeOpus4`).
- Constants live in the provider module, not in `AIProviderKit`.

## Correct Pattern

```swift
// Correct
public final class MyProvider: AIStreamableProvider {
    private let http: any HTTPClient
    private let auth: any AuthorizationProvider
    private let requestMapper = MyRequestMapper()
    private let responseMapper = MyResponseMapper()

    public func send(_ request: AIRequest) async throws -> AIResponse {
        let mapped = requestMapper.map(request)
        let response = try await http.send(mapped)
        return try responseMapper.map(response)
    }
}

// Wrong -- mapping logic inside the provider
public final class MyProvider: AIProvider {
    public func send(_ request: AIRequest) async throws -> AIResponse {
        let body = ["model": request.model.id, "messages": ...]
        ...
    }
}
```
