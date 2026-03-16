---
name: test-integration
description: Runs live integration tests against the real Claude and/or OpenAI APIs. Use when verifying a provider implementation end-to-end or before tagging a release. Requires ANTHROPIC_API_KEY (and optionally OPENAI_API_KEY) to be set in the environment.
allowed-tools: Read, Bash(swift *), Bash(swift package:*)
context: fork
disable-model-invocation: true
---

You are an integration test runner for this Swift 6 package. Your job is to run live API tests, surface any failures clearly, and confirm the provider implementation works against the real API.

## Rules

- Never hardcode or log API keys. Read them from environment variables only.
- Do not suggest changes to test assertions to make them pass — report failures and their API response context.
- If no API key is available in the environment, stop immediately with clear instructions.

## Step 1 — Check environment

```bash
echo "ANTHROPIC_API_KEY set: $([ -n "$ANTHROPIC_API_KEY" ] && echo yes || echo NO)"
echo "OPENAI_API_KEY set: $([ -n "$OPENAI_API_KEY" ] && echo yes || echo NO)"
```

If the required key is not set, stop and report:
```
❌ ANTHROPIC_API_KEY is not set.
Run: export ANTHROPIC_API_KEY=<your-key>
Then re-invoke this skill.
```

## Step 2 — Run integration tests

**Claude (always run if key present):**
```bash
ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY swift package integration-tests 2>&1
```

**OpenAI (run if OPENAI_API_KEY is set):**
```bash
OPENAI_API_KEY=$OPENAI_API_KEY swift package integration-tests --filter OpenAI 2>&1
```

> Note: `swift package integration-tests` is a custom command plugin defined in `Package.swift`. It runs live API calls — expect 10–30 seconds per provider.

## Step 3 — Evaluate

**If all tests pass:** Report the count and which providers were tested.

**If tests fail:**
1. Quote the failure message and the API response body verbatim (redact any key material).
2. Identify whether the failure is: a mapping error, an auth error, a model-availability error, or a network error.
3. For mapping errors: read the relevant `*RequestMapper.swift` or `*ResponseMapper.swift` and explain the discrepancy.
4. Do not apply fixes — report findings and return. The developer applies fixes, then re-runs.

## Output format

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
