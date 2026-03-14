---
name: Add Tool or Skill
description: Add a new Tool, ToolGroup, or Skill to AIProviderKit with tests. Chooses the right construct automatically.
mode: agent
---

Add a new AIProviderKit capability: `${input:toolName:Tool or skill name (e.g. WeatherTool)}`.

You are a Swift 6 capability engineer. Choose the right construct, implement it correctly with `JSONSchema` / `JSONValue`, and write tests.

## Boundaries

✅ Always do autonomously:
- Read `CalendarTool.swift` and `Tool.swift` before writing anything
- Choose the construct based on the decision table below
- Write tests with given/when/then for both happy path and missing input
- Run the three verification commands before finishing

⚠️ Ask before:
- Using platform APIs (EventKit, CoreLocation, Reminders) — confirm entitlements exist
- Deciding to put a Skill inside AIProviderKit core (Skills belong in consuming apps)
- Adding external dependencies

🚫 Never:
- Use `Any`, `[String: Any]`, `Encodable` without a concrete type
- Capture mutable state inside a tool handler
- Use XCTest — always Swift Testing (`@Suite`, `@Test`, `#expect`)
- Call `URLSession` or network APIs from a tool handler

## Choose the right construct

| Situation | Use |
|---|---|
| Single action | `Tool` (standalone constant) |
| 2+ related actions (e.g. list + create + delete) | `ToolGroup` enum in `Sources/AIProviderKit/Tools/` |
| Tools + prompt template + post-processing | `Skill` protocol (in consuming app, not core) |

## Reference files to read first

```
Sources/AIProviderKit/Tools/CalendarTool.swift
Sources/AIProviderKit/Protocols/ToolGroup.swift
Sources/AIProviderKit/Models/Tool.swift
Sources/AIProviderKit/Protocols/Skill.swift
Sources/AIProviderKit/Models/Recipe.swift
```

## Implementation rules

```swift
// ✅ Correct ToolGroup
public enum ${input:toolName}: ToolGroup {
    public static var all: [Tool] { [actionOne, actionTwo] }

    public static let actionOne = Tool(
        name: "${input:toolName:snake_case}_action",
        description: "One sentence the model uses to decide when to call this.",
        inputSchema: .object(
            properties: ["param": .string(description: "…")],
            required: ["param"]
        )
    ) { input async throws in
        let param = input["param"]?.stringValue ?? ""
        return .object(["success": .bool(true), "result": .string(param)])
    }
}

// ✅ Registration (in doc comment):
/// await client.toolRegistry.registerAll(${input:toolName}.self)

// ❌ Wrong — mutable captured state
var cache: [String: String] = [:]
let tool = Tool(...) { input async throws in
    cache["key"] = "value"  // ❌ not @Sendable-safe
    ...
}
```

**JSONSchema types:** `.string`, `.integer`, `.number`, `.boolean`, `.array(items:)`, `.object(properties:required:)`

**JSONValue accessors:** `.stringValue`, `.intValue`, `.boolValue`, `.doubleValue`, `.arrayValue`, `.objectValue`

## Test structure

```swift
@Suite("${input:toolName}")
struct ${input:toolName}Tests {

    @Test("returns success with valid input")
    func execute_validInput_returnsSuccess() async throws {
        // Given
        let input = JSONValue.object(["param": .string("value")])
        // When
        let result = try await ${input:toolName}.actionOne.execute(with: input)
        // Then
        #expect(result["success"]?.boolValue == true)
    }

    @Test("handles missing required input")
    func execute_missingInput_returnsFailure() async throws {
        // Given
        let input = JSONValue.object([:])
        // When
        let result = try await ${input:toolName}.actionOne.execute(with: input)
        // Then
        #expect(result["success"]?.boolValue == false)
    }
}
```

Tests go in `Tests/AIProviderKitTests/Tools/` (create the folder if needed).

## Acceptance criteria

```bash
swift build
swift test --filter AIProviderKitTests
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
```

All three must exit clean.
