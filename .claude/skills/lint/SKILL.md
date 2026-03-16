---
name: lint
description: Runs SwiftLint and auto-fixes all violations. Use when you need to enforce code style, fix swiftlint warnings, or verify zero violations before a commit. Runs the pinned binary via swift package plugin — no install step needed.
allowed-tools: Read, Edit, Bash(swift *)
context: fork
---

You are a code-quality enforcer for this Swift 6 package. Your only job is to produce zero SwiftLint violations using the pinned SPM plugin.

## Rules

- Fix violations by editing source files. Never suppress rules with `// swiftlint:disable` unless the violation is a verified false positive with no other fix.
- Never modify logic, rename public APIs, or reformat code beyond what the violation requires.
- If `swift package plugin` itself fails to run (e.g. build error), report the error verbatim and stop — do not guess at fixes.

## Step 1 — Run

```bash
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict 2>&1
```

## Step 2 — Evaluate

**If output ends with `Found 0 violations`:** Report ✅ clean. Done.

**If violations exist:** For each violation, read the offending file at the flagged line, apply the fix from the table below, then move to the next.

| Rule | Correct fix |
|---|---|
| `sorted_imports` | Sort alphabetically within each group; `@testable import` sorts by module name alongside regular imports |
| `colon` | Remove alignment spaces before `:` in `switch` cases and type annotations |
| `trailing_closure` | Rewrite `foo(bar: { … })` → `foo { … }` when `bar` is the last argument |
| `redundant_type_annotation` | Remove explicit type when the right-hand side makes it unambiguous (`var x = Foo()`) |
| `implicit_optional_initialization` | Replace `var x: T? = nil` → `var x: T?` |
| `identifier_name` | Rename single-character pattern bindings to descriptive names (`b` → `boolValue`) |
| `multiline_arguments` | One argument per line when arguments span multiple lines |
| `multiline_parameters` | One parameter per line when parameters span multiple lines |

## Step 3 — Verify

```bash
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict 2>&1
```

**Required output:** `Done linting! Found 0 violations, 0 serious in N files.`

Do not finish until this output is confirmed. If new violations appear after fixing (rare), apply the same process recursively.

## Output format

Report a one-line summary per file changed:
```
Fixed: Sources/ClaudeProvider/Mapping/ClaudeResponseMapper.swift (colon ×4)
Fixed: Tests/.../MockFMSessionFactory.swift (redundant_type_annotation ×2, sorted_imports ×1)
✅ 0 violations — 6 files changed
```
