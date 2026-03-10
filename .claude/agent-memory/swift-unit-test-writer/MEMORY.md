# Agent Memory - Swift Unit Test Writer

## Project: AIProviderKit SPM Package

### Module Names
- `@testable import AIProviderKit` — core module
- `@testable import ClaudeProvider` — Claude provider module
- `import AIProviderKit` — used from ClaudeProviderTests since types are public

### Build Configuration
- Package.swift specifies `.macOS(.v13)` but `@Observable` (AILogStore) requires macOS 14+
- `swift test` fails on macOS due to `@Observable` and `AIProviderKitUI` using iOS-only SwiftUI APIs
- **Use xcodebuild on iOS Simulator**: `xcodebuild test -scheme AIProviderKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1'`
- Filter test targets: `-only-testing:AIProviderKitTests -only-testing:ClaudeProviderTests`

### Existing Mock Types (in Tests/)
- `MockAIProvider` — conforms to `AIProvider`, stored `stubbedResponse/stubbedError`
- `SequentialMockProvider` — returns responses in sequence for multi-turn tests
- `MockData` — static fixtures: `response`, `toolUseResponse`, `request()`, `weatherTool`
- `MockSkill` — conforms to `Skill`, configurable via init params
- `MockHTTPClient` — conforms to `HTTPClient` (ClaudeProvider internal protocol)

### Key Patterns
- All registries (`ToolRegistry`, `SkillRegistry`, `RecipeRegistry`) are `actor` types — tests must be `async`
- `AILogStore` is `@MainActor` — tests need `@MainActor` annotation with justification comment
- `AIClient` is an `actor` — all interactions are `async`
- `ClaudeRequestMapper` and `ClaudeResponseMapper` are `struct` types with `internal` access — use `@testable import ClaudeProvider`
- `ClaudeModels.swift` types (`ClaudeResponse`, `ClaudeContentBlock`, etc.) are `internal` — need `@testable import`

### Test File Locations
- AIProviderKitTests: `Tests/AIProviderKitTests/{Category}/{TypeName}Tests.swift`
- ClaudeProviderTests: `Tests/ClaudeProviderTests/{Category}/{TypeName}Tests.swift`
- Mocks: `Tests/{Target}Tests/Mocks/`

### Common Gotchas
- `TokenUsageTests` needs `import Foundation` for JSONEncoder/JSONDecoder
- `JSONSchemaTests` needs `import Foundation` for JSONSerialization
- ClaudeProvider `MockAPIKeyAuthorization` is private in ClaudeProviderTests.swift — cannot reuse from other files
