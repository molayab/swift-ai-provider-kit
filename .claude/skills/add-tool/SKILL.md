---
name: add-tool
description: Add a new Tool or ToolGroup to AIProviderKit following the JSONSchema/JSONValue pattern, or add a Skill that bundles tools with a Recipe. Use when the user wants to give the AI model a new callable capability.
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Edit, Write, Bash, Glob, Grep
argument-hint: "[ToolName | SkillName]"
---

# Add a Tool or Skill: $ARGUMENTS

Decide which construct fits the request:

| Goal | Use |
|---|---|
| Single callable action for the model | `Tool` (inline or standalone) |
| Multiple related actions (e.g. list + create + delete) | `ToolGroup` enum in `Sources/AIProviderKit/Tools/` |
| Bundle tools + prompt template + post-processing | `Skill` protocol |

Read the existing examples before writing anything:
- `Sources/AIProviderKit/Tools/CalendarTool.swift` — canonical `ToolGroup` pattern
- `Sources/AIProviderKit/Protocols/ToolGroup.swift` — `ToolGroup` protocol
- `Sources/AIProviderKit/Models/Tool.swift` — `Tool` struct definition
- `Sources/AIProviderKit/Protocols/Skill.swift` — `Skill` protocol
- `Sources/AIProviderKit/Models/Recipe.swift` — `Recipe` for prompt templates

---

## Option A — ToolGroup (preferred for related tools)

File: `Sources/AIProviderKit/Tools/$ARGUMENTSTool.swift`

```swift
import Foundation   // only if needed for platform APIs

/// Ready-to-use `Tool`s for $ARGUMENTS operations.
///
/// ```swift
/// await client.toolRegistry.registerAll($ARGUMENTSTool.self)
/// ```
public enum $ARGUMENTSTool: ToolGroup {

    public static var all: [Tool] { [$ACTION_ONE, $ACTION_TWO] }

    // MARK: - $ACTION_ONE

    public static let $ACTION_ONE = Tool(
        name: "$ARGUMENTS_SNAKE_action_one",
        description: "Clear, one-sentence description the model uses to decide when to call this.",
        inputSchema: .object(
            properties: [
                "paramName": .string(description: "What this parameter is."),
                "optionalParam": .integer(description: "Optional. Default: 10.")
            ],
            required: ["paramName"]
        )
    ) { input async throws in
        // Extract inputs — all values are JSONValue, use typed accessors:
        //   input["key"]?.stringValue
        //   input["key"]?.intValue
        //   input["key"]?.boolValue
        //   input["key"]?.doubleValue
        //   input["key"]?.arrayValue
        //   input["key"]?.objectValue

        let param = input["paramName"]?.stringValue ?? ""

        // Perform the operation...

        // Return JSONValue — use .object([...]) for structured results:
        return .object([
            "success": .bool(true),
            "result": .string("...")
        ])
    }
}
```

### Registration (document in the tool's docstring)

```swift
await client.toolRegistry.registerAll($ARGUMENTSTool.self)
```

---

## Option B — Standalone Tool (for a single action)

Register inline or define as a `static let` constant:

```swift
let $ARGUMENTSTool = Tool(
    name: "$ARGUMENTS_SNAKE",
    description: "...",
    inputSchema: .object(
        properties: ["key": .string(description: "...")],
        required: ["key"]
    )
) { input async throws in
    return .string("result")
}

await client.toolRegistry.register($ARGUMENTSTool)
```

---

## Option C — Skill (tool bundle + recipe + post-processing)

File: define in the consuming app/module (Skills are not part of AIProviderKit core).

```swift
import AIProviderKit

struct $ARGUMENTSSkill: Skill {

    let identifier = "$ARGUMENTS_LOWERCASED"
    let description = "What this skill does in one sentence."
    let tools: [Tool] = [$ARGUMENTSTool.$ACTION_ONE]

    // Optional: provide a prompt template
    let recipe: Recipe? = Recipe(
        id: "$ARGUMENTS_LOWERCASED",
        name: "$ARGUMENTS",
        systemPrompt: "You are a specialist in $ARGUMENTS.",
        userPromptTemplate: "Perform $ARGUMENTS on: {{input}}"
    )

    func process(response: AIResponse) async throws -> SkillResult {
        SkillResult(output: response.text, usage: response.usage)
    }
}

// Registration:
await client.skillRegistry.register($ARGUMENTSSkill())
```

---

## JSONSchema reference

Use `JSONSchema` for `inputSchema`. Common patterns:

```swift
// String field
.string(description: "...")

// Integer with description
.integer(description: "...")

// Boolean
.boolean(description: "...")

// Object with required + optional fields
.object(
    properties: [
        "required_field": .string(description: "..."),
        "optional_field": .integer(description: "Optional.")
    ],
    required: ["required_field"]
)

// Array of strings
.array(items: .string(description: "One item."), description: "List of items.")
```

All tool inputs arrive as `JSONValue` and outputs must be `JSONValue`.

---

## Step — Write tests

Tests live in `Tests/AIProviderKitTests/` in the appropriate subfolder. Mirror the existing structure — there is no dedicated `Tools/` test folder; tool tests belong in `Registries/` or a new `Tools/` subfolder.

```swift
import AIProviderKit
import Foundation
import Testing

@Suite("$ARGUMENTSTool")
struct $ARGUMENTSToolTests {

    @Test("executes with valid input")
    func execute_validInput_returnsSuccess() async throws {
        // Given
        let input = JSONValue.object(["paramName": .string("value")])

        // When
        let result = try await $ARGUMENTSTool.$ACTION_ONE.execute(with: input)

        // Then
        #expect(result["success"]?.boolValue == true)
    }

    @Test("handles missing required input")
    func execute_missingInput_returnsError() async throws {
        // Given
        let input = JSONValue.object([:])

        // When
        let result = try await $ARGUMENTSTool.$ACTION_ONE.execute(with: input)

        // Then
        #expect(result["success"]?.boolValue == false)
    }
}
```

---

## Verify

```bash
swift build
swift test --filter AIProviderKitTests
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
```

All three must pass with zero errors and zero violations.
