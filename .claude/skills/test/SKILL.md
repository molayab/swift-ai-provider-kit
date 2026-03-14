---
name: test
description: Run the full Swift Testing suite (no API key required) and summarize results. Use when the user asks to run tests, check test status, or verify nothing is broken.
disable-model-invocation: false
user-invocable: true
allowed-tools: Bash, Read
argument-hint: "[--filter TestSuiteName]"
---

# Run Tests

Run the test suite using Swift Testing. All tests are mocked — no API key or network access required.

## Commands

Run all tests:
```bash
swift test 2>&1
```

Run a specific suite or test (when `$ARGUMENTS` is provided):
```bash
swift test --filter $ARGUMENTS 2>&1
```

Available targets:
- `AIProviderKitTests` — core models, builders, registries, AIClient
- `ClaudeProviderTests` — ClaudeProvider request/response mappers (uses MockHTTPClient)
- `AppleIntelligenceProviderTests` — AppleIntelligenceProvider mappers and session logic

## Interpret results

After running, report:
1. Total tests passed / failed
2. Any failing test names with the failure message
3. If failures exist, read the relevant source files and diagnose the root cause before suggesting a fix

## Important notes

- Tests use Swift Testing (`@Suite`, `@Test`, `#expect`) — not XCTest
- `--xunit-output` does not work with Swift Testing; use plain output only
- Integration tests (live API) run separately: `ANTHROPIC_API_KEY=... swift package integration-tests`
- Never modify a test to make it pass by weakening assertions; fix the implementation instead
