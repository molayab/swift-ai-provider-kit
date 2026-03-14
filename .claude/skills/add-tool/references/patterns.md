# Tool & Skill Implementation Patterns

Complete Swift code patterns for each construct. Replace `$ARGUMENTS`, `$ACTION`, `$ARGUMENTS_SNAKE` with actual names.

---

## Option A — ToolGroup (2+ related actions)

File: `Sources/AIProviderKit/Tools/$ARGUMENTSTool.swift`

```swift
import Foundation   // Add only if needed for platform APIs

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
        description: "One sentence the model uses to decide when to call this tool.",
        inputSchema: .object(
            properties: [
                "requiredParam": .string(description: "Description of this parameter."),
                "optionalParam": .integer(description: "Optional. Defaults to 10.")
            ],
            required: ["requiredParam"]
        )
    ) { input async throws in
        let param = input["requiredParam"]?.stringValue ?? ""
        let count = input["optionalParam"]?.intValue ?? 10

        // Perform the operation...

        return .object([
            "success": .bool(true),
            "result": .string("…")
        ])
    }

    // MARK: - $ACTION_TWO

    public static let $ACTION_TWO = Tool(
        name: "$ARGUMENTS_SNAKE_action_two",
        description: "…",
        inputSchema: .object(
            properties: [:],
            required: []
        )
    ) { _ async throws in
        return .object(["success": .bool(true)])
    }
}
```

---

## Option B — Standalone Tool (single action)

```swift
let $ARGUMENTSTool = Tool(
    name: "$ARGUMENTS_SNAKE",
    description: "One sentence the model uses to decide when to call this.",
    inputSchema: .object(
        properties: [
            "key": .string(description: "…")
        ],
        required: ["key"]
    )
) { input async throws in
    let value = input["key"]?.stringValue ?? ""
    return .string(value)
}

// Register:
await client.toolRegistry.register($ARGUMENTSTool)
```

---

## Option C — Skill (tools + recipe + post-processing)

Defined in the consuming app/module — not inside `AIProviderKit` core.

```swift
import AIProviderKit

struct $ARGUMENTSSkill: Skill {

    let identifier = "$ARGUMENTS_LOWERCASED"
    let description = "What this skill does in one sentence."

    let tools: [Tool] = [
        $ARGUMENTSTool.$ACTION_ONE
    ]

    let recipe: Recipe? = Recipe(
        id: "$ARGUMENTS_LOWERCASED",
        name: "$ARGUMENTS",
        systemPrompt: "You are a specialist in $ARGUMENTS. Be concise and precise.",
        userPromptTemplate: "Perform $ARGUMENTS on the following:\n\n{{input}}"
    )

    func process(response: AIResponse) async throws -> SkillResult {
        SkillResult(output: response.text, usage: response.usage)
    }
}

// Register:
await client.skillRegistry.register($ARGUMENTSSkill())
```

---

## JSONSchema Quick Reference

```swift
.string(description: "A text value.")
.integer(description: "A whole number.")
.number(description: "A decimal number.")
.boolean(description: "true or false.")

.object(
    properties: [
        "required_field": .string(description: "Always required."),
        "optional_field": .integer(description: "Optional.")
    ],
    required: ["required_field"]
)

.array(items: .string(description: "One element."), description: "A list of strings.")
```

---

## JSONValue Accessor Quick Reference

```swift
input["key"]?.stringValue   // String?
input["key"]?.intValue      // Int?
input["key"]?.boolValue     // Bool?
input["key"]?.doubleValue   // Double?
input["key"]?.arrayValue    // [JSONValue]?
input["key"]?.objectValue   // [String: JSONValue]?
```

Return `JSONValue` from every handler:
```swift
.null
.bool(true)
.integer(42)
.double(3.14)
.string("result")
.array([.string("a"), .string("b")])
.object(["success": .bool(true), "value": .string("…")])
```
