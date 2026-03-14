---
name: Add Provider
description: Scaffold a complete new AI provider following the AIProviderKit mapper pattern
mode: agent
---

Implement a new AIProviderKit provider following the project's Open/Closed Principle — no changes to `AIClient` or existing providers are needed.

## Instructions

1. Ask the user for the provider name if not already specified.

2. Read these reference files before writing anything:
   - `Documentation/AddingAProvider.md`
   - `Sources/ClaudeProvider/ClaudeProvider.swift`
   - `Sources/ClaudeProvider/Mapping/ClaudeRequestMapper.swift`
   - `Sources/ClaudeProvider/Mapping/ClaudeResponseMapper.swift`
   - `Sources/ClaudeProvider/Models/ClaudeModels.swift`
   - `Sources/ClaudeProvider/Networking/HTTPClient.swift`
   - `Sources/ClaudeProvider/Authorization/APIKeyAuthorization.swift`
   - `Package.swift`

3. Create the following file structure (mirroring ClaudeProvider):

```
Sources/<Name>Provider/
├── <Name>Provider.swift
├── Authorization/
│   └── <Name>Authorization.swift
├── Mapping/
│   ├── <Name>RequestMapper.swift
│   └── <Name>ResponseMapper.swift
├── Models/
│   └── <Name>Models.swift           # AIModel constants + internal Codable types
└── Networking/
    ├── HTTPClient.swift
    └── URLSession<Name>Client.swift

Tests/<Name>ProviderTests/
├── <Name>ProviderTests.swift
├── Authorization/
│   └── <Name>AuthorizationTests.swift
├── Mapping/
│   ├── <Name>RequestMapperTests.swift
│   └── <Name>ResponseMapperTests.swift
└── Mocks/
    └── MockHTTPClient.swift
```

4. Register the target in `Package.swift` (product + target + test target), including `SwiftLintBuildToolPlugin`.

5. Enforce these rules throughout:
   - Mapping logic lives exclusively in `<Name>RequestMapper` and `<Name>ResponseMapper`
   - `ContentBlock` is the only content type crossing into AIProviderKit
   - `JSONValue` for all tool inputs/outputs — never `Any` or `[String: Any]`
   - API keys via `AuthorizationProvider` — never hardcoded
   - `async/await` throughout — no GCD or callbacks
   - Full `Sendable` compliance (Swift 6 strict concurrency)

6. Write tests for all mappers using `MockHTTPClient`. Every test follows given / when / then with comments.

7. Verify with:
   ```
   swift build
   swift test --filter <Name>ProviderTests
   swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
   ```
