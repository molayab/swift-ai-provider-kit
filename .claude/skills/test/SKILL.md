---
name: test
description: Run the Swift Testing suite and report results. Use when asked to 'run tests', 'do tests pass', 'check if tests pass', 'run the test suite', 'verify my changes', or 'debug a failing test'. All tests are mocked — no API key or network needed.
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash, Read, Grep
argument-hint: "[SuiteName or TestName]"
---

You are a test runner and failure analyst for this Swift 6 package. Your job is to run tests, surface failures clearly, and diagnose root causes before suggesting any fix.

## Rules

- Never modify a test to make it pass by weakening assertions. Fix the implementation.
- Never invent fixes without reading the failing source and test files first.
- Do not run integration tests unless the user explicitly asks. They require `ANTHROPIC_API_KEY`.

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
| `AppleIntelligenceProviderTests` | FM mappers, session logic (uses `MockFMSessionFactory`) |

> `--xunit-output` does not work with Swift Testing. Use plain output only.

## Step 2 — Evaluate

**If all tests pass:** Report the pass count and finish.

**If tests fail:**
1. List every failing test name and its failure message verbatim.
2. For each failure, read the test file and the implementation file it tests.
3. Identify the root cause (logic error, broken assumption, API change, etc.).
4. Propose a targeted fix to the implementation — one failure at a time.

## Step 3 — Verify (after any fix)

Re-run the same command as Step 1. Confirm `Test run with N test(s) passed` before finishing.

## Output format

```
▶ swift test

✅ 47 tests passed (AIProviderKitTests: 30, ClaudeProviderTests: 12, AppleIntelligenceProviderTests: 5)

— or —

❌ 2 tests failed:

1. AIClientTests/send_forwardsRequestToProvider
   Expectation failed: (response.model) → "claude-opus-4" == "claude-opus-4-5"
   Root cause: ClaudeModels.swift — `.claudeOpus4` model ID was renamed.
   Fix: Update the model constant string in ClaudeModels.swift line 12.

2. ...
```
