---
name: Add Tool
description: Add a new Tool, ToolGroup, or Skill to AIProviderKit with tests
mode: agent
---

Add a new callable tool or skill to AIProviderKit following the project's `JSONSchema` / `JSONValue` pattern.

## Instructions

1. Ask the user what the tool should do if not already clear.

2. Read these reference files first:
   - `Sources/AIProviderKit/Models/Tool.swift`
   - `Sources/AIProviderKit/Protocols/ToolGroup.swift`
   - `Sources/AIProviderKit/Protocols/Skill.swift`
   - `Sources/AIProviderKit/Models/Recipe.swift`
   - `Sources/AIProviderKit/Tools/CalendarTool.swift` (canonical ToolGroup example)

3. Choose the right construct:
   - **ToolGroup** — multiple related tools (e.g. list + create + delete). File goes in `Sources/AIProviderKit/Tools/`.
   - **Standalone Tool** — single action, defined inline or as a constant.
   - **Skill** — bundles tools with a `Recipe` prompt template and post-processing logic.

4. Implement using these constraints:
   - `inputSchema` must use `JSONSchema` (`.object`, `.string`, `.integer`, `.boolean`, `.array`)
   - All handler inputs are `JSONValue` — extract via `.stringValue`, `.intValue`, `.boolValue`, etc.
   - All handler outputs must be `JSONValue` — return `.object([...])` for structured results
   - Handlers are `@Sendable` — no captured mutable state
   - `ToolGroup` conformance uses `enum`, not `struct` or `class`

5. Document the registration pattern in the tool's doc comment:
   ```swift
   /// ```swift
   /// await client.toolRegistry.registerAll(MyTool.self)
   /// ```
   ```

6. Write tests in `Tests/AIProviderKitTests/`:
   - Test happy path with valid `JSONValue` input
   - Test graceful handling of missing or invalid input
   - Follow given / when / then with comments
   - Use `@Suite` and `@Test` (Swift Testing) — never XCTest

7. Verify:
   ```
   swift build
   swift test --filter AIProviderKitTests
   swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
   ```
