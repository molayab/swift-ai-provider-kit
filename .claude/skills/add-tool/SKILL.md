---
name: add-tool
description: Adds a new Tool, ToolGroup, or Skill to AIProviderKit. Use when asked to 'add a tool', 'create a new tool', 'give the model a new capability', 'add a skill', 'add a recipe', or 'implement [action] as a tool'. Chooses the right construct (Tool / ToolGroup / Skill) based on the request.
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(swift *)
argument-hint: "[ToolName or SkillName]"
---

You are a Swift 6 capability engineer for AIProviderKit. Your job is to add the right callable construct, wired up correctly with `JSONSchema` / `JSONValue`, and tested.

## Constraints

✅ Always: use `JSONSchema` for `inputSchema`, `JSONValue` for all handler I/O, `enum` for `ToolGroup`, `@Sendable` handlers with no captured mutable state

✅ Always: every tool — even one that wraps a single action — must be a `ToolGroup` enum. Standalone `let` constants are not used in this codebase.

⚠️ Ask first: if the tool needs platform entitlements (e.g. EventKit, CoreLocation, Reminders) — confirm the consuming app has them before referencing platform APIs

🚫 Never: use `Any`, `[String: Any]`, `Encodable` without a concrete type, or captured mutable state in a tool handler

🚫 Never: create a top-level `let` constant as a tool. All tools live inside a `ToolGroup` enum.

## Step 1 — Choose the right construct

| Request | Use |
|---|---|
| Single action | `ToolGroup` enum with one entry in `all` |
| 2+ related actions (list/create/delete) | `ToolGroup` enum with multiple entries in `all` |
| Tools + prompt template + post-processing | `Skill` protocol (in consuming app, not core) |

Every `ToolGroup` automatically gets a `tool()` throwing function (protocol extension) for single-tool groups:
```swift
try CurrentTimeTool.tool()  // same as CurrentTimeTool.all[0]
```

## Step 2 — Read the canonical examples first

```
Sources/AIProviderTools/CurrentTimeTool.swift   ← canonical single-tool ToolGroup
Sources/AIProviderTools/CalendarTool.swift      ← canonical multi-tool ToolGroup
Sources/AIProviderKit/Protocols/ToolGroup.swift ← protocol + tool extension
Sources/AIProviderKit/Models/Tool.swift
Sources/AIProviderKit/Protocols/Skill.swift
Sources/AIProviderKit/Models/Recipe.swift
```

## Step 3 — Implement

New tools go in `Sources/AIProviderTools/$ARGUMENTSTool.swift`.

See `references/patterns.md` for complete Swift code templates for each option.

**Key rules for all tools:**
- `inputSchema` uses `JSONSchema` — `.object`, `.string`, `.integer`, `.boolean`, `.array(items:)`
- Handler inputs: `input["key"]?.stringValue` / `.intValue` / `.boolValue` / `.doubleValue` / `.arrayValue`
- Handler outputs: always `JSONValue` — use `.object(["success": .bool(true), ...])` for structured results
- Handlers are `@Sendable` — no captured mutable state; use platform singletons (`EKEventStore()`) inside the closure

**Registration** (document in the group's doc comment):
```swift
// Single-tool group
await client.toolRegistry.registerAll(CurrentTimeTool.self)

// Multi-tool group
await client.toolRegistry.registerAll(CalendarTool.self)
```

## Step 4 — Write tests

Tests live in `Tests/AIProviderToolsTests/`. File name: `$ARGUMENTSToolTests.swift`.

```swift
import Testing
import AIProviderKit
import AIProviderTools

@Suite("$ARGUMENTSTool")
struct $ARGUMENTSToolTests {

    // MARK: - ToolGroup

    @Test("all contains exactly N tools")
    func allCount() {
        #expect($ARGUMENTSTool.all.count == 1) // adjust N
    }

    @Test("tool returns the same instance as all[0]")
    func toolMatchesAll() {
        #expect($ARGUMENTSTool.tool.name == $ARGUMENTSTool.all[0].name)
    }

    // MARK: - Metadata

    @Test("tool has correct name")
    func name() {
        #expect($ARGUMENTSTool.$ACTION.name == "$ARGUMENTS_SNAKE")
    }

    // MARK: - Execution

    @Test("returns success with valid input")
    func execute_validInput_returnsSuccess() async throws {
        // given
        let input = JSONValue.object(["paramName": .string("value")])
        // when
        let result = try await $ARGUMENTSTool.$ACTION.execute(with: input)
        // then
        #expect(result["success"]?.boolValue == true)
    }

    @Test("handles missing required input gracefully")
    func execute_missingInput_returnsFailure() async throws {
        // given
        let input = JSONValue.object([:])
        // when
        let result = try await $ARGUMENTSTool.$ACTION.execute(with: input)
        // then
        #expect(result["error"] != nil)
    }
}
```

## Step 5 — Verify (in order)

```bash
swift build
swift test --filter AIProviderToolsTests
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
```

All three must exit clean before finishing.
