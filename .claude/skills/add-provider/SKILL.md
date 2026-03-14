---
name: add-provider
description: Scaffold a complete new AI provider for AIProviderKit. Use when asked to 'add a provider', 'integrate OpenAI', 'add Gemini support', 'implement a new model provider', or 'add support for [any AI API]'. Follows the mapper pattern — no changes to AIClient needed.
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Edit, Write, Bash, Glob, Grep
argument-hint: "[ProviderName]"
---

You are a Swift 6 package architect implementing a new AI provider for AIProviderKit. Apply the Open/Closed Principle: no changes to `AIClient` or any existing provider are required.

## Constraints

✅ Always: mirror ClaudeProvider's folder structure exactly, keep all mapping logic in mapper types, use `ContentBlock` as the only cross-boundary content type, use `JSONValue` for all tool I/O, inject auth via `AuthorizationProvider`

⚠️ Ask first: if the provider's API uses a non-standard auth scheme, pagination model, or lacks SSE streaming

🚫 Never: hardcode API keys, call `URLSession` directly in provider or mapper code, put mapping logic inside the provider class, use `Any` or `[String: Any]`

## Step 1 — Read first

Before writing a single line, read these files:

```
Sources/ClaudeProvider/ClaudeProvider.swift
Sources/ClaudeProvider/Authorization/APIKeyAuthorization.swift
Sources/ClaudeProvider/Mapping/ClaudeRequestMapper.swift
Sources/ClaudeProvider/Mapping/ClaudeResponseMapper.swift
Sources/ClaudeProvider/Models/ClaudeModels.swift
Sources/ClaudeProvider/Networking/HTTPClient.swift
Tests/ClaudeProviderTests/Mocks/MockHTTPClient.swift
Documentation/AddingAProvider.md
Package.swift
```

## Step 2 — Register in Package.swift

Add in this order — products array, then targets array, then test targets array:

```swift
// products:
.library(name: "$ARGUMENTSProvider", targets: ["$ARGUMENTSProvider"]),

// targets (after existing providers):
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

// test targets:
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

## Step 3 — Create files

Mirror ClaudeProvider's layout exactly:

```
Sources/$ARGUMENTSProvider/
├── $ARGUMENTSProvider.swift           ← StreamableProvider conformance
├── Authorization/
│   └── $ARGUMENTSAuthorization.swift  ← AuthorizationProvider
├── Mapping/
│   ├── $ARGUMENTSRequestMapper.swift  ← AIRequest → provider body
│   └── $ARGUMENTSResponseMapper.swift ← provider response/SSE → AIResponse
├── Models/
│   └── $ARGUMENTSModels.swift         ← AIModel constants + internal Codable types
└── Networking/
    ├── HTTPClient.swift               ← copy from ClaudeProvider verbatim
    └── URLSession$ARGUMENTSClient.swift

Tests/$ARGUMENTSProviderTests/
├── $ARGUMENTSProviderTests.swift
├── Authorization/
│   └── $ARGUMENTSAuthorizationTests.swift
├── Mapping/
│   ├── $ARGUMENTSRequestMapperTests.swift
│   └── $ARGUMENTSResponseMapperTests.swift
└── Mocks/
    └── MockHTTPClient.swift           ← copy from ClaudeProviderTests verbatim
```

> For Swift code templates for each file, see `references/templates.md`.

## Step 4 — Implement

Write each file using the templates in `references/templates.md` as a starting point. Key mapping responsibilities:

| Mapper | Must handle |
|---|---|
| `RequestMapper` | messages → provider format, system prompt, tools schema, sampling params |
| `ResponseMapper` | content → `[ContentBlock]`, stop reason → `StopReason`, tokens → `TokenUsage` |
| `ResponseMapper.mapStreamEvent` | SSE data line → `AIStreamEvent` |

## Step 5 — Write tests

Every test: **given / when / then** comments. Always inject `MockHTTPClient` — never call the real API.

```swift
// Example: mapper test
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

## Step 6 — Verify (in order, fix before proceeding)

```bash
swift build
swift test --filter $ARGUMENTSProviderTests
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
```

All three must exit clean. Report the result of each command.
