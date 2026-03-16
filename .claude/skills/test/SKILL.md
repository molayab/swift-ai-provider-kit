---
name: test
description: Runs the Swift Testing suite and reports results. Use when a regression check is needed, tests may be failing, or before confirming a fix is complete. No argument or filter name → unit tests (mocked, no API key required). 'live' or 'integration' argument → live API tests against real Claude/OpenAI endpoints (requires ANTHROPIC_API_KEY).
allowed-tools: Read, Grep, Bash(swift *), Bash(swift package:*)
context: fork
argument-hint: "[SuiteName | TestName | live | integration]"
---

You are a test runner and failure analyst for this Swift 6 package. Run tests, surface failures clearly, and diagnose root causes before suggesting any fix.

## Rules

- Never modify a test to make it pass by weakening assertions. Fix the implementation.
- Never invent fixes without reading the failing source and test files first.
- If `$ARGUMENTS` starts with `live` or `integration`, go to **Integration mode**. Otherwise run **Unit mode**.

---

## Unit mode (default)

Runs mocked tests — no API key required.

### Step 1 — Run

**All tests** (no `$ARGUMENTS` or unrecognised filter):
```bash
swift test 2>&1
```

**Filtered** (when `$ARGUMENTS` is a suite/test name):
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

### Step 2 — Evaluate

**If all tests pass:** Report the pass count per target and finish.

**If tests fail:**
1. List every failing test name and its failure message verbatim.
2. For each failure, read the test file and the implementation file it tests in parallel.
3. Identify the root cause (logic error, broken assumption, API change, etc.).
4. Propose a targeted fix to the implementation — one failure at a time.

### Step 3 — Verify (after any fix)

Re-run the same command as Step 1. Confirm all tests pass before finishing.

---

## Integration mode (`$ARGUMENTS` starts with `live` or `integration`)

Runs live API tests against real Claude and/or OpenAI endpoints.

### Step 1 — Check environment

```bash
echo "ANTHROPIC_API_KEY set: $([ -n "$ANTHROPIC_API_KEY" ] && echo yes || echo NO)"
echo "OPENAI_API_KEY set: $([ -n "$OPENAI_API_KEY" ] && echo yes || echo NO)"
```

If `ANTHROPIC_API_KEY` is not set, stop immediately and report:
```
❌ ANTHROPIC_API_KEY is not set.
Run: export ANTHROPIC_API_KEY=<your-key>
Then re-invoke: /test live
```

### Step 2 — Run integration tests

**Claude (always run if key present):**
```bash
ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY swift package integration-tests 2>&1
```

**OpenAI (run if OPENAI_API_KEY is set):**
```bash
OPENAI_API_KEY=$OPENAI_API_KEY swift package integration-tests --filter OpenAI 2>&1
```

> `swift package integration-tests` is a custom command plugin defined in `Package.swift`. It runs live API calls — expect 10–30 seconds per provider.

### Step 3 — Evaluate

**If all tests pass:** Report the count and which providers were tested.

**If tests fail:**
1. Quote the failure message and the API response body verbatim (redact any key material).
2. Identify whether the failure is: a mapping error, an auth error, a model-availability error, or a network error.
3. For mapping errors: read the relevant `*RequestMapper.swift` or `*ResponseMapper.swift` and explain the discrepancy.
4. Do not apply fixes — report findings and return. The developer applies fixes, then re-runs.

---

## Output format

```
▶ swift test [--filter <arg>]

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

Integration mode output:

```
## Integration Test Report

**Providers tested:** Claude ✅  |  OpenAI ⚠️ (key not set, skipped)

### Claude
✅ 12/12 tests passed  — or —  ❌ 2/12 failed:

1. ClaudeStreamingTests/streamText_receivesDeltas
   Error: Unexpected stop_reason "end_turn" — expected "stop"
   Likely cause: ClaudeResponseMapper.mapStopReason — string mismatch.

### Summary
✅ Integration tests confirm provider is production-ready.
— or —
❌ Fix N failures before tagging release.
```
