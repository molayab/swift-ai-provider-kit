# Integration Tests

Integration tests run against the **real provider APIs** and verify that the full
request/response cycle works end-to-end. They are intentionally kept separate from
the unit test suite so they never run in CI by default and never require API keys
to pass the build.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| API key | `ANTHROPIC_API_KEY` environment variable set to a valid Anthropic key |
| Network | Outbound HTTPS to `api.anthropic.com` |
| Platform | macOS 14+ (the tests are a command-line executable) |

---

## Running

### Via the SPM command plugin (recommended)

```bash
ANTHROPIC_API_KEY=sk-ant-... swift package integration-tests
```

This builds the `IntegrationTests` executable if needed and runs it in one step.

### Directly

```bash
ANTHROPIC_API_KEY=sk-ant-... swift run IntegrationTests
```

### In CI (opt-in)

Store `ANTHROPIC_API_KEY` as a GitHub Actions secret, then add a separate
workflow or job:

```yaml
- name: Integration tests
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: swift package integration-tests
```

Keep integration tests in a separate workflow (e.g. `integration.yml`) triggered
manually or on a schedule, not on every push, to control API costs.

---

## What is tested

All tests run against `claude-haiku-4-5` (fastest / lowest cost model) and are
located in `Sources/IntegrationTests/ClaudeIntegrationSuite.swift`.

| Test | AIClient method | What it checks |
|---|---|---|
| **Basic text completion** | `send(_:)` | Non-empty text response, `stopReason == .endTurn` |
| **Streaming** | `stream(_:)` | `textDelta` events received, collected string non-empty |
| **Automatic tool execution** | `send(_:)` with `ToolRegistry` | Model calls `get_current_time`, client auto-executes it, final `endTurn` response |
| **Recipe rendering** | `send(recipe:values:model:)` | `{{text}}` and `{{language}}` placeholders substituted, response non-empty |
| **Skill execution** | `execute(skillId:input:model:)` | `SummarizerSkill` registered, executed, `SkillResult.output` non-empty |

---

## Project structure

```
Sources/IntegrationTests/
├── IntegrationApp.swift          @main entry — guards for ANTHROPIC_API_KEY
├── ClaudeIntegrationSuite.swift  Actor with test runner and all test cases
└── SummarizerSkill.swift         Skill fixture used by the skill test

Plugins/RunIntegrationTests/
└── RunIntegrationTestsPlugin.swift  SPM command plugin (verb: integration-tests)
```

---

## Adding a new test case

1. Open `Sources/IntegrationTests/ClaudeIntegrationSuite.swift`.
2. Add a private `async throws` method following the given / when / then pattern:

```swift
private func testMyFeature() async throws {
    // given
    let request = try AIRequestBuilder()
        .model(.claudeHaiku4)
        .addMessage(.user(text: "..."))
        .maxTokens(64)
        .build()

    // when
    let response = try await client.send(request)

    // then
    guard !response.text.isEmpty else { throw IntegrationError.emptyResponse }
}
```

3. Register it in `runAll()`:

```swift
await run("My feature") { try await self.testMyFeature() }
```

---

## Adding a new provider

When a new provider is added (e.g. OpenAI), create a parallel suite:

```
Sources/IntegrationTests/
└── OpenAIIntegrationSuite.swift   mirrors ClaudeIntegrationSuite
```

Then invoke both suites from `IntegrationApp.main()`, guarded by their respective
environment variables (`OPENAI_API_KEY`, etc.).
