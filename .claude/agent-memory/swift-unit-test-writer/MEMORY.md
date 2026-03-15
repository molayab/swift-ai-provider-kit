# Agent Memory - Swift Unit Test Writer

## Project: AIProviderKit SPM Package

### Module Names
- `@testable import AIProviderKit` — core module
- `@testable import ClaudeProvider` — Claude provider module
- `@testable import OpenAIProvider` — OpenAI provider module
- `import AIProviderKit` — used from provider tests since types are public
- `import AIProviderTools` — ready-to-use ToolGroup implementations (no @testable needed, all types are public)

### Build & Test
- `swift test` works directly on macOS — all targets build and pass
- Platform minimum: iOS 26+, macOS 26+, watchOS 11+, tvOS 26+, visionOS 2+

### Existing Mock Types (in Tests/)
- `MockAIProvider` — conforms to `AIProvider`, stored `stubbedResponse/stubbedError`
- `SequentialMockProvider` — returns responses in sequence for multi-turn tests
- `MockData` — static fixtures: `response`, `toolUseResponse`, `request()`, `weatherTool`
- `MockSkill` — conforms to `Skill`, configurable via init params
- `MockHTTPClient` — conforms to `HTTPClient` (ClaudeProvider internal protocol)
- `MockHTTPClient` — conforms to `HTTPClient` (OpenAIProvider internal protocol, at `Tests/OpenAIProviderTests/Mocks/`)

### Key Patterns
- All registries (`ToolRegistry`, `SkillRegistry`, `RecipeRegistry`) are `actor` types — tests must be `async`
- `AILogStore` is `@MainActor` — tests need `@MainActor` annotation with justification comment
- `AIClient` is an `actor` — all interactions are `async`
- `ClaudeRequestMapper` and `ClaudeResponseMapper` are `struct` types with `internal` access — use `@testable import ClaudeProvider`
- `ClaudeModels.swift` types (`ClaudeResponse`, `ClaudeContentBlock`, etc.) are `internal` — need `@testable import`
- `OpenAIRequestMapper` and `OpenAIResponseMapper` are `struct` types with `internal` access — use `@testable import OpenAIProvider`
- `OpenAIModels.swift` types (`OpenAIChatResponse`, `OpenAIChoice`, etc.) are `internal` — need `@testable import`

### Test File Locations
- AIProviderKitTests: `Tests/AIProviderKitTests/{Category}/{TypeName}Tests.swift`
- ClaudeProviderTests: `Tests/ClaudeProviderTests/{Category}/{TypeName}Tests.swift`
- OpenAIProviderTests: `Tests/OpenAIProviderTests/{Category}/{TypeName}Tests.swift`
- AIProviderToolsTests: `Tests/AIProviderToolsTests/{TypeName}Tests.swift`
- Mocks: `Tests/{Target}Tests/Mocks/`

### ToolGroup Pattern (AIProviderTools module)
- Every tool is a `ToolGroup` enum — even single-action tools. No standalone `let` constants.
- Single-tool groups: `CurrentTimeTool`, `LocationTool`, `ShellCommandTool` (macOS-only)
- Multi-tool groups: `CalendarTool` (2 tools), `RemindersTool` (2 tools)
- `ToolGroup` protocol extension provides `static var tool: Tool` (returns `all[0]`) for direct access
- Tests for any `ToolGroup` must cover: `all.count`, `tool.name == all[0].name`, metadata, and execution
- `ShellCommandTool` is `#if os(macOS)` — guard test suite with same conditional

### Common Gotchas
- `TokenUsageTests` needs `import Foundation` for JSONEncoder/JSONDecoder
- `JSONSchemaTests` needs `import Foundation` for JSONSerialization
- ClaudeProvider `MockAPIKeyAuthorization` is private in ClaudeProviderTests.swift — cannot reuse from other files
