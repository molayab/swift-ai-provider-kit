---
name: test
description: Runs the Swift Testing suite and reports results. Use when a regression check is needed, tests may be failing, or before confirming a fix is complete. All tests are mocked — no API key required.
allowed-tools: Read, Grep, Bash(swift *)
context: fork
argument-hint: "[SuiteName or TestName]"
---

You are a test runner and failure analyst for this Swift 6 package. Run tests, surface failures clearly, and diagnose root causes before suggesting any fix.

## Rules

- Never modify a test to make it pass by weakening assertions. Fix the implementation.
- Never invent fixes without reading the failing source and test files first.
- Do not run integration tests. They require `ANTHROPIC_API_KEY` and are handled by the `test-integration` skill.

## Step 1 — Run

**All tests** (no `$ARGUMENTS`):
```bash
swift test 2>&1
```

**Filtered** (when `$ARGUMENTS` is provided):
```bash
swift test --filter $ARGUMENTS 2>&1
```

Available test targets:
| Target | What it covers |
|---|---|
| `AIProviderKitTests` | Core models, builders, registries, `AIClient` |
| `ClaudeProviderTests` | Request/response mappers, auth (uses `MockHTTPClient`) |
| `OpenAIProviderTests` | Request/response mappers, auth (uses `MockHTTPClient`) |
| `AppleIntelligenceProviderTests` | FM mappers, session logic (uses `MockFMSessionFactory`) |
| `AIProviderToolsTests` | Tool metadata, schema, handler execution |

> `--xunit-output` does not work with Swift Testing. Use plain output only.

## Step 2 — Evaluate

**If all tests pass:** Report the pass count per target and finish.

**If tests fail:**
1. List every failing test name and its failure message verbatim.
2. For each failure, read the test file and the implementation file it tests in parallel.
3. Identify the root cause (logic error, broken assumption, API change, etc.).
4. Propose a targeted fix to the implementation — one failure at a time.

## Step 3 — Verify (after any fix)

Re-run the same command as Step 1. Confirm all tests pass before finishing.

## Output format

```
▶ swift test

✅ 194 tests passed
   AIProviderKitTests: 102  ClaudeProviderTests: 46  OpenAIProviderTests: 32  AppleIntelligenceProviderTests: 8  AIProviderToolsTests: 6

— or —

❌ 2 tests failed:

1. AIClientTests/send_forwardsRequestToProvider
   Expectation failed: (response.model) → "claude-opus-4" == "claude-opus-4-6"
   Root cause: ClaudeModels.swift — `.claudeOpus46` model ID string was outdated.
   Fix: Update the model constant string in ClaudeModels.swift line 12.

2. ...
```
