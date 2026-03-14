---
name: Add Provider
description: Scaffold a complete new AI provider following the AIProviderKit mapper pattern. No changes to AIClient needed.
mode: agent
---

Scaffold a complete new AIProviderKit provider named `${input:providerName:Provider name (e.g. OpenAI)}`.

You are a Swift 6 package architect. Apply the Open/Closed Principle — no changes to `AIClient` or existing providers are required.

## Boundaries

✅ Always do autonomously:
- Read existing provider source files before writing anything
- Mirror the ClaudeProvider folder structure exactly
- Register the target in `Package.swift` (product + target + test target + `SwiftLintBuildToolPlugin`)
- Run `swift build`, `swift test --filter ${input:providerName}ProviderTests`, and `swift package plugin swiftlint lint --strict` in sequence

⚠️ Ask before:
- Using a non-standard auth scheme (not Bearer token)
- Deciding the provider doesn't need streaming support
- Choosing which model constants to expose

🚫 Never:
- Hardcode API keys or secrets
- Call `URLSession` directly in provider or mapper code
- Place mapping logic inside the provider class
- Use `Any`, `[String: Any]`, or `AnyCodable`
- Modify `AIClient`, `AIProviderKit` core types, or other providers

## Reference files to read first

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

## Required file structure

```
Sources/${input:providerName}Provider/
├── ${input:providerName}Provider.swift           ← StreamableProvider
├── Authorization/
│   └── ${input:providerName}Authorization.swift  ← AuthorizationProvider
├── Mapping/
│   ├── ${input:providerName}RequestMapper.swift  ← AIRequest → provider body
│   └── ${input:providerName}ResponseMapper.swift ← response/SSE → AIResponse
├── Models/
│   └── ${input:providerName}Models.swift         ← AIModel constants + Codable types
└── Networking/
    ├── HTTPClient.swift                          ← copy from ClaudeProvider
    └── URLSession${input:providerName}Client.swift

Tests/${input:providerName}ProviderTests/
├── ${input:providerName}ProviderTests.swift
├── Authorization/
│   └── ${input:providerName}AuthorizationTests.swift
├── Mapping/
│   ├── ${input:providerName}RequestMapperTests.swift
│   └── ${input:providerName}ResponseMapperTests.swift
└── Mocks/
    └── MockHTTPClient.swift                      ← copy from ClaudeProviderTests
```

## Implementation rules

- All mapping logic belongs in `RequestMapper` and `ResponseMapper` — never in the provider class
- `ContentBlock` (`.text`, `.image`, `.toolUse`, `.toolResult`) is the only content type that crosses into AIProviderKit
- `JSONValue` for all tool inputs and outputs
- Full `Sendable` compliance — Swift 6 strict concurrency is enforced on all targets
- `async/await` throughout — no GCD, no callbacks

## Test requirements

Every test: `@Suite`, `@Test`, `#expect` (Swift Testing — never XCTest). Structure:
```swift
@Test("maps model identifier")
func map_setsModelIdentifier() {
    // Given … // When … // Then …
}
```
Always inject `MockHTTPClient` — never call the real API.

## Acceptance criteria

All three commands must exit clean:
```bash
swift build
swift test --filter ${input:providerName}ProviderTests
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
```
