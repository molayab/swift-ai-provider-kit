---
name: add
description: Scaffolds new code for AIProviderKit. First word of the argument routes to the right workflow. 'provider <Name>' scaffolds a complete new AI provider (mapper pattern, no changes to AIClient). 'tool <Name>' adds a new ToolGroup, Tool, or Skill. Use when asked to 'add a provider', 'add Gemini support', 'add a tool', 'create a new tool', 'give the model a new capability', or 'implement [action] as a tool'.
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(swift *)
argument-hint: "provider <ProviderName>  |  tool <ToolName>"
---

You are a Swift 6 package architect for AIProviderKit. The first word of `$ARGUMENTS` selects the workflow.

- **`provider <Name>`** → scaffold a new AI provider
- **`tool <Name>`** → add a new ToolGroup / Tool / Skill

If `$ARGUMENTS` is missing or does not start with `provider` or `tool`, ask the user which workflow they want before proceeding.

---

## provider workflow

`$PROVIDER` = everything after the first word (e.g. `GeminiProvider`)

Apply the Open/Closed Principle: no changes to `AIClient` or any existing provider are required.

### Constraints

✅ Always: mirror ClaudeProvider's folder structure exactly, keep all mapping logic in mapper types, use `ContentBlock` as the only cross-boundary content type, use `JSONValue` for all tool I/O, inject auth via `AuthorizationProvider`

⚠️ Ask first: if the provider's API uses a non-standard auth scheme, pagination model, or lacks SSE streaming

🚫 Never: hardcode API keys, call `URLSession` directly in provider or mapper code, put mapping logic inside the provider class, use `Any` or `[String: Any]`

### Step 1 — Read first

Before writing a single line, read these files in parallel:

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

### Step 2 — Register in Package.swift

Add in this order — products array, then targets array, then test targets array:

```swift
// products:
.library(name: "$PROVIDER", targets: ["$PROVIDER"]),

// targets (after existing providers):
.target(
    name: "$PROVIDER",
    dependencies: ["AIProviderKit"],
    path: "Sources/$PROVIDER",
    swiftSettings: [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("StrictConcurrency")
    ],
    plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
),

// test targets:
.testTarget(
    name: "${PROVIDER}Tests",
    dependencies: ["$PROVIDER", "AIProviderKit"],
    path: "Tests/${PROVIDER}Tests",
    swiftSettings: [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("StrictConcurrency")
    ],
    plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
),
```

### Step 3 — Create files

Mirror ClaudeProvider's layout exactly:

```
Sources/$PROVIDER/
├── $PROVIDER.swift                      ← StreamableProvider conformance
├── Authorization/
│   └── ${PROVIDER}Authorization.swift  ← AuthorizationProvider
├── Mapping/
│   ├── ${PROVIDER}RequestMapper.swift  ← AIRequest → provider body
│   └── ${PROVIDER}ResponseMapper.swift ← provider response/SSE → AIResponse
├── Models/
│   └── ${PROVIDER}Models.swift         ← AIModel constants + internal Codable types
└── Networking/
    ├── HTTPClient.swift                 ← copy from ClaudeProvider verbatim
    └── URLSession${PROVIDER}Client.swift

Tests/${PROVIDER}Tests/
├── ${PROVIDER}Tests.swift
├── Authorization/
│   └── ${PROVIDER}AuthorizationTests.swift
├── Mapping/
│   ├── ${PROVIDER}RequestMapperTests.swift
│   └── ${PROVIDER}ResponseMapperTests.swift
└── Mocks/
    └── MockHTTPClient.swift             ← copy from ClaudeProviderTests verbatim
```

> For Swift code templates for each file, see `references/templates.md` in the `add-provider` skill directory.

### Step 4 — Implement

Key mapping responsibilities:

| Mapper | Must handle |
|---|---|
| `RequestMapper` | messages → provider format, system prompt, tools schema, sampling params |
| `ResponseMapper` | content → `[ContentBlock]`, stop reason → `StopReason`, tokens → `TokenUsage` |
| `ResponseMapper.mapStreamEvent` | SSE data line → `AIStreamEvent` |

### Step 5 — Write tests

Every test: **given / when / then** comments. Always inject `MockHTTPClient` — never call the real API.

```swift
@Suite("${PROVIDER}RequestMapper")
struct ${PROVIDER}RequestMapperTests {
    private let sut = ${PROVIDER}RequestMapper()

    @Test("maps model identifier")
    func map_setsModelIdentifier() {
        // Given
        let request = AIRequest(model: .PROVIDER_MODEL_CONSTANT, messages: [])
        // When
        let mapped = sut.map(request)
        // Then
        #expect(mapped.model == "provider-model-id")
    }
}
```

### Step 6 — Verify (in order, fix before proceeding)

```bash
swift build
swift test --filter ${PROVIDER}Tests
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
```

All three must exit clean. Report the result of each command.

---

## tool workflow

`$TOOL` = everything after the first word (e.g. `WeatherTool`)

You are a Swift 6 capability engineer for AIProviderKit. Add the right callable construct, wired up correctly with `JSONSchema` / `JSONValue`, and tested.

### Constraints

✅ Always: use `JSONSchema` for `inputSchema`, `JSONValue` for all handler I/O, `enum` for `ToolGroup`, `@Sendable` handlers with no captured mutable state

✅ Always: every tool — even one that wraps a single action — must be a `ToolGroup` enum. Standalone `let` constants are not used in this codebase.

⚠️ Ask first: if the tool needs platform entitlements (e.g. EventKit, CoreLocation, Reminders) — confirm the consuming app has them before referencing platform APIs

🚫 Never: use `Any`, `[String: Any]`, `Encodable` without a concrete type, or captured mutable state in a tool handler

🚫 Never: create a top-level `let` constant as a tool. All tools live inside a `ToolGroup` enum.

### Step 1 — Choose the right construct

| Request | Use |
|---|---|
| Single action | `ToolGroup` enum with one entry in `all` |
| 2+ related actions (list/create/delete) | `ToolGroup` enum with multiple entries in `all` |
| Tools + prompt template + post-processing | `Skill` protocol (in consuming app, not core) |

Every `ToolGroup` automatically gets a `tool()` throwing function (protocol extension) for single-tool groups:
```swift
try CurrentTimeTool.tool()  // same as CurrentTimeTool.all[0]
```

### Step 2 — Read the canonical examples first

```
Sources/AIProviderTools/CurrentTimeTool.swift   ← canonical single-tool ToolGroup
Sources/AIProviderTools/CalendarTool.swift      ← canonical multi-tool ToolGroup
Sources/AIProviderKit/Protocols/ToolGroup.swift ← protocol + tool extension
Sources/AIProviderKit/Models/Tool.swift
Sources/AIProviderKit/Protocols/Skill.swift
Sources/AIProviderKit/Models/Recipe.swift
```

### Step 3 — Implement

New tools go in `Sources/AIProviderTools/${TOOL}.swift`.

**Key rules for all tools:**
- `inputSchema` uses `JSONSchema` — `.object`, `.string`, `.integer`, `.boolean`, `.array(items:)`
- Handler inputs: `input["key"]?.stringValue` / `.intValue` / `.boolValue` / `.doubleValue` / `.arrayValue`
- Handler outputs: always `JSONValue` — use `.object(["success": .bool(true), ...])` for structured results
- Handlers are `@Sendable` — no captured mutable state; use platform singletons (`EKEventStore()`) inside the closure

**Registration** (document in the group's doc comment):
```swift
// Single-tool group
await client.toolRegistry.registerAll(${TOOL}.self)

// Multi-tool group
await client.toolRegistry.registerAll(${TOOL}.self)
```

### Step 4 — Write tests

Tests live in `Tests/AIProviderToolsTests/`. File name: `${TOOL}Tests.swift`.

```swift
import Testing
import AIProviderKit
import AIProviderTools

@Suite("$TOOL")
struct ${TOOL}Tests {

    // MARK: - ToolGroup

    @Test("all contains exactly N tools")
    func allCount() {
        #expect($TOOL.all.count == 1) // adjust N
    }

    @Test("tool returns the same instance as all[0]")
    func toolMatchesAll() {
        #expect($TOOL.tool.name == $TOOL.all[0].name)
    }

    // MARK: - Execution

    @Test("returns success with valid input")
    func execute_validInput_returnsSuccess() async throws {
        // given
        let input = JSONValue.object(["paramName": .string("value")])
        // when
        let result = try await $TOOL.ACTION.execute(with: input)
        // then
        #expect(result["success"]?.boolValue == true)
    }

    @Test("handles missing required input gracefully")
    func execute_missingInput_returnsFailure() async throws {
        // given
        let input = JSONValue.object([:])
        // when
        let result = try await $TOOL.ACTION.execute(with: input)
        // then
        #expect(result["error"] != nil)
    }
}
```

### Step 5 — Verify (in order)

```bash
swift build
swift test --filter AIProviderToolsTests
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
```

All three must exit clean before finishing.
