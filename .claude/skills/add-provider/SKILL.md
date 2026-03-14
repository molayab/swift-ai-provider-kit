---
name: add-provider
description: Implement a complete new AI provider (e.g. OpenAI, Gemini) following the AIProviderKit mapper pattern, including Package.swift registration, mapper pair, HTTPClient, model constants, and unit tests. Use when the user wants to add support for a new AI model provider.
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Edit, Write, Bash, Glob, Grep
argument-hint: "[ProviderName]"
---

# Add a New AI Provider: $ARGUMENTS

Implement `$ARGUMENTS` as a first-class AIProviderKit provider. The Open/Closed Principle applies — no changes to `AIClient` or any existing provider are required.

Reference: `Documentation/AddingAProvider.md`

---

## Step 1 — Read existing providers first

Before writing anything, read `ClaudeProvider` (the canonical HTTP-based reference):

```
Sources/ClaudeProvider/ClaudeProvider.swift
Sources/ClaudeProvider/Authorization/APIKeyAuthorization.swift
Sources/ClaudeProvider/Mapping/ClaudeRequestMapper.swift
Sources/ClaudeProvider/Mapping/ClaudeResponseMapper.swift
Sources/ClaudeProvider/Models/ClaudeModels.swift
Sources/ClaudeProvider/Networking/HTTPClient.swift
Sources/ClaudeProvider/Networking/URLSessionHTTPClient.swift
Tests/ClaudeProviderTests/ClaudeProviderTests.swift
Tests/ClaudeProviderTests/Mocks/MockHTTPClient.swift
```

---

## Step 2 — Register in Package.swift

Add to `Package.swift` (products first, then targets, then test targets):

```swift
// products array:
.library(name: "$ARGUMENTSProvider", targets: ["$ARGUMENTSProvider"]),

// targets array:
.target(
    name: "$ARGUMENTSProvider",
    dependencies: ["AIProviderKit"],
    path: "Sources/$ARGUMENTSProvider",
    swiftSettings: [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("StrictConcurrency")
    ],
    plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
),

// test targets array:
.testTarget(
    name: "$ARGUMENTSProviderTests",
    dependencies: ["$ARGUMENTSProvider", "AIProviderKit"],
    path: "Tests/$ARGUMENTSProviderTests",
    swiftSettings: [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("StrictConcurrency")
    ],
    plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
),
```

---

## Step 3 — Create the file structure

Mirror the ClaudeProvider layout exactly:

```
Sources/$ARGUMENTSProvider/
├── $ARGUMENTSProvider.swift              # Provider class (root of the folder)
├── Authorization/
│   └── $ARGUMENTSAuthorization.swift     # AuthorizationProvider conformance
├── Mapping/
│   ├── $ARGUMENTSRequestMapper.swift     # AIRequest → provider request body
│   └── $ARGUMENTSResponseMapper.swift    # provider response/SSE → AIResponse / AIStreamEvent
├── Models/
│   └── $ARGUMENTSModels.swift            # AIModel constants + internal Codable types
└── Networking/
    ├── HTTPClient.swift                  # copy of the HTTPClient protocol from ClaudeProvider
    └── URLSession$ARGUMENTSClient.swift  # URLSession-backed implementation

Tests/$ARGUMENTSProviderTests/
├── $ARGUMENTSProviderTests.swift         # Provider-level integration tests (MockHTTPClient)
├── Authorization/
│   └── $ARGUMENTSAuthorizationTests.swift
├── Mapping/
│   ├── $ARGUMENTSRequestMapperTests.swift
│   └── $ARGUMENTSResponseMapperTests.swift
└── Mocks/
    └── MockHTTPClient.swift
```

---

## Step 4 — Implement each file

### `$ARGUMENTSProvider.swift`

```swift
import AIProviderKit
import Foundation

public final class $ARGUMENTSProvider: StreamableProvider, Sendable {

    public let identifier = "$ARGUMENTS_LOWERCASED"
    public let capabilities: Set<AICapability> = [.text, .tools, .streaming, .systemPrompt]

    private let authorization: any AuthorizationProvider
    private let httpClient: any HTTPClient
    private let requestMapper = $ARGUMENTSRequestMapper()
    private let responseMapper = $ARGUMENTSResponseMapper()

    public init(
        authorization: any AuthorizationProvider,
        httpClient: any HTTPClient = URLSession$ARGUMENTSClient()
    ) {
        self.authorization = authorization
        self.httpClient = httpClient
    }

    public func send(_ request: AIRequest) async throws -> AIResponse {
        let headers = try await authorization.authorizationHeaders()
        let mapped = requestMapper.map(request)
        let data = try await httpClient.send(mapped, headers: headers)
        return try responseMapper.map(data, model: request.model.id)
    }

    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let headers = try await self.authorization.authorizationHeaders()
                    let mapped = self.requestMapper.map(request)
                    for try await chunk in self.httpClient.stream(mapped, headers: headers) {
                        let event = try self.responseMapper.mapStreamEvent(chunk)
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

### `Authorization/$ARGUMENTSAuthorization.swift`

```swift
import AIProviderKit
import Foundation

public struct $ARGUMENTSAuthorization: AuthorizationProvider, Sendable {

    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func authorizationHeaders() async throws -> [String: String] {
        ["Authorization": "Bearer \(apiKey)"]
    }
}
```

### `Mapping/$ARGUMENTSRequestMapper.swift`

```swift
import AIProviderKit
import Foundation

struct $ARGUMENTSRequestMapper: Sendable {

    func map(_ request: AIRequest) -> $ARGUMENTSRequest {
        // Convert AIRequest → provider-specific Codable struct.
        // Map ContentBlock array → provider message format.
        // Map Tool definitions → provider tool/function schema.
        // Map sampling params (temperature, topP, maxTokens).
    }
}
```

### `Mapping/$ARGUMENTSResponseMapper.swift`

```swift
import AIProviderKit
import Foundation

struct $ARGUMENTSResponseMapper: Sendable {

    func map(_ data: Data, model: String) throws -> AIResponse {
        // Decode provider JSON → AIResponse.
        // Map provider content → [ContentBlock].
        // Map stop reason string → StopReason.
        // Map token counts → TokenUsage.
    }

    func mapStreamEvent(_ data: Data) throws -> AIStreamEvent {
        // Parse SSE event line → AIStreamEvent.
    }
}
```

### `Models/$ARGUMENTSModels.swift`

```swift
import AIProviderKit

// MARK: - AIModel constants

public extension AIModel {
    static let $ARGUMENTS_MODEL_CONSTANT = AIModel("provider-model-id")
}

// MARK: - Internal Codable types

struct $ARGUMENTSRequest: Encodable, Sendable { … }
struct $ARGUMENTSResponse: Decodable, Sendable { … }
```

### `Networking/HTTPClient.swift`

Copy verbatim from `Sources/ClaudeProvider/Networking/HTTPClient.swift` — each provider owns its own copy of this protocol so they remain independently deployable.

---

## Step 5 — Write tests

Every test uses **given / when / then** comments. Inject `MockHTTPClient` — never hit the real API.

```swift
import AIProviderKit
import Foundation
import Testing
@testable import $ARGUMENTSProvider

@Suite("$ARGUMENTSRequestMapper")
struct $ARGUMENTSRequestMapperTests {

    private let sut = $ARGUMENTSRequestMapper()

    @Test("maps model identifier")
    func map_setsModelIdentifier() {
        // Given
        let request = AIRequest(model: .$ARGUMENTS_MODEL_CONSTANT, messages: [])

        // When
        let mapped = sut.map(request)

        // Then
        #expect(mapped.model == "provider-model-id")
    }
}
```

---

## Step 6 — Verify

Run in order; fix any error before moving to the next:

```bash
swift build
swift test --filter $ARGUMENTSProviderTests
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
```

All three must pass with zero errors and zero violations before the implementation is complete.
