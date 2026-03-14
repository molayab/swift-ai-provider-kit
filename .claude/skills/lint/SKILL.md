---
name: lint
description: Run SwiftLint via the pinned SPM plugin (0.63.2) and fix all violations. Use when the user asks to lint, check style, or fix SwiftLint issues.
disable-model-invocation: false
user-invocable: true
allowed-tools: Bash, Read, Edit
argument-hint: "[--fix]"
---

# SwiftLint

Run SwiftLint using the pinned SPM binary plugin (version locked in `Package.resolved`).

## Step 1 — Lint

Run:

```bash
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict 2>&1
```

## Step 2 — Evaluate results

- If `Found 0 violations` → report clean, done.
- If violations exist → read each offending file and fix every violation by editing the source directly. Do not suppress rules with `// swiftlint:disable` unless the violation is a known false positive that cannot be fixed otherwise.

## Violation fix reference

| Rule | Fix |
|---|---|
| `sorted_imports` | Sort `import` statements alphabetically within each group; `@testable import` sorts by module name alongside regular imports |
| `colon` | Remove alignment spaces before `:` in `switch` cases and type annotations |
| `trailing_closure` | Rewrite `foo(bar: { … })` as `foo { … }` when `bar` is the last argument |
| `redundant_type_annotation` | Remove explicit type on `var` when the right-hand side makes it unambiguous |
| `implicit_optional_initialization` | Replace `var x: T? = nil` with `var x: T?` |
| `identifier_name` | Rename single-character pattern bindings to descriptive names (e.g. `b` → `boolValue`) |
| `multiline_arguments` | Place each argument on its own line when arguments span multiple lines |

## Step 3 — Verify

Re-run the lint command. Only finish when the output confirms `0 violations`.
