---
name: add-tool
description: Add a new Tool, ToolGroup, or Skill to AIProviderKit. Use when asked to 'add a tool', 'create a new tool', 'give the model a new capability', 'add a skill', 'add a recipe', or 'implement [action] as a tool'. Chooses the right construct (Tool / ToolGroup / Skill) based on the request.
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Edit, Write, Bash, Glob, Grep
argument-hint: "[ToolName or SkillName]"
---

You are a Swift 6 capability engineer for AIProviderKit. Your job is to add the right callable construct, wired up correctly with `JSONSchema` / `JSONValue`, and tested.

## Constraints

✅ Always: use `JSONSchema` for `inputSchema`, `JSONValue` for all handler I/O, `enum` for `ToolGroup`, `@Sendable` handlers with no captured mutable state

⚠️ Ask first: if the tool needs platform entitlements (e.g. EventKit, CoreLocation, Reminders) — confirm the consuming app has them before referencing platform APIs

🚫 Never: use `Any`, `[String: Any]`, `Encodable` without a concrete type, or captured mutable state in a tool handler

## Step 1 — Choose the right construct

| Request | Use |
|---|---|
| Single action | `Tool` (standalone constant) |
| 2+ related actions (list/create/delete) | `ToolGroup` enum in `Sources/AIProviderKit/Tools/` |
| Tools + prompt template + post-processing | `Skill` protocol (in consuming app, not core) |

## Step 2 — Read the canonical example first

```
Sources/AIProviderKit/Tools/CalendarTool.swift  ← canonical ToolGroup
Sources/AIProviderKit/Protocols/ToolGroup.swift
Sources/AIProviderKit/Models/Tool.swift
Sources/AIProviderKit/Protocols/Skill.swift
Sources/AIProviderKit/Models/Recipe.swift
```

## Step 3 — Implement

See `references/patterns.md` for complete Swift code templates for each option.

**Key rules for all tools:**
- `inputSchema` uses `JSONSchema` — `.object`, `.string`, `.integer`, `.boolean`, `.array(items:)`
- Handler inputs: `input["key"]?.stringValue` / `.intValue` / `.boolValue` / `.doubleValue` / `.arrayValue`
- Handler outputs: always `JSONValue` — use `.object(["success": .bool(true), ...])` for structured results
- Handlers are `@Sendable` — no captured mutable state; use platform singletons (`EKEventStore()`) inside the closure

**ToolGroup registration** (document in the group's doc comment):
```swift
await client.toolRegistry.registerAll($ARGUMENTSTool.self)
```

## Step 4 — Write tests

Tests live in `Tests/AIProviderKitTests/`. Mirror existing subfolder structure. Create a new `Tools/` subfolder if none exists.

```swift
import AIProviderKit
import Testing

@Suite("$ARGUMENTSTool")
struct $ARGUMENTSToolTests {

    @Test("returns success with valid input")
    func execute_validInput_returnsSuccess() async throws {
        // Given
        let input = JSONValue.object(["paramName": .string("value")])
        // When
        let result = try await $ARGUMENTSTool.$ACTION.execute(with: input)
        // Then
        #expect(result["success"]?.boolValue == true)
    }

    @Test("handles missing required input gracefully")
    func execute_missingInput_returnsFailure() async throws {
        // Given
        let input = JSONValue.object([:])
        // When
        let result = try await $ARGUMENTSTool.$ACTION.execute(with: input)
        // Then
        #expect(result["success"]?.boolValue == false)
    }
}
```

## Step 5 — Verify (in order)

```bash
swift build
swift test --filter AIProviderKitTests
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
```

All three must exit clean before finishing.
