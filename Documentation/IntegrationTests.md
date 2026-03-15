# Integration Tests

Integration tests run against **real provider APIs and on-device models** and verify that the full
request/response cycle works end-to-end. They are intentionally kept separate from
the unit test suite so they never run in CI by default and never require API keys
to pass the build.

---

## Suites

| Suite | File | Prerequisite |
|---|---|---|
| **Claude** | `ClaudeIntegrationSuite.swift` | `ANTHROPIC_API_KEY` env var |
| **Apple Intelligence** | `AppleIntelligenceIntegrationSuite.swift` | Apple Intelligence enabled device (iOS 26+ / macOS 26+) |

---

## Prerequisites

### Claude suite

| Requirement | Detail |
|---|---|
| API key | `ANTHROPIC_API_KEY` environment variable set to a valid Anthropic key |
| Network | Outbound HTTPS to `api.anthropic.com` |
| Platform | macOS 26+ (the tests are a command-line executable) |

### Apple Intelligence suite

| Requirement | Detail |
|---|---|
| Device | Apple Intelligence enabled (iPhone 15 Pro / iPad / Apple Silicon Mac) |
| OS | iOS 26+ or macOS 26+ |
| Network | Not required (on-device inference) |

---

## Running

### Via the SPM command plugin (recommended)

```bash
# Claude suite
ANTHROPIC_API_KEY=sk-ant-... swift package integration-tests claude

# Apple Intelligence suite (no API key needed)
swift package integration-tests apple-intelligence

# Both suites (skips any that are unavailable)
ANTHROPIC_API_KEY=sk-ant-... swift package integration-tests all
```

### Directly

```bash
ANTHROPIC_API_KEY=sk-ant-... swift run IntegrationTests claude
swift run IntegrationTests apple-intelligence
```

### In CI (opt-in)

Store `ANTHROPIC_API_KEY` as a GitHub Actions secret, then add a separate
workflow or job:

```yaml
- name: Integration tests
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: swift package integration-tests claude
```

Keep integration tests in a separate workflow (e.g. `integration.yml`) triggered
manually or on a schedule, not on every push, to control API costs.

The Apple Intelligence suite requires a physical Apple Silicon device and cannot
run on GitHub Actions runners — it exits gracefully with a warning when
`AppleIntelligenceAvailability.isAvailable` is `false`.

---

## What is tested

Both suites run the same five test scenarios against their respective providers.

| Test | AIClient method | What it checks |
|---|---|---|
| **Basic text completion** | `send(_:)` | Non-empty text response, `stopReason == .endTurn` |
| **Streaming** | `stream(_:)` | `textDelta` events received, collected string non-empty |
| **Automatic tool execution** | `send(_:)` with `ToolRegistry` | Model calls `get_current_time`, client auto-executes it, final `endTurn` response |
| **Recipe rendering** | `send(recipe:values:model:)` | `{{text}}` and `{{language}}` placeholders substituted, response non-empty |
| **Skill execution** | `execute(skillId:input:model:)` | `SummarizerSkill` registered, executed, `SkillResult.output` non-empty |

Claude tests use `claude-haiku-4-5` (fastest / lowest cost model).
Apple Intelligence tests use `.appleIntelligenceDefault`.

---

## Project structure

```
Sources/IntegrationTests/
├── IntegrationApp.swift                       @main entry — routes to suite by CLI argument
├── ClaudeIntegrationSuite.swift               Claude (Anthropic API) test cases
├── AppleIntelligenceIntegrationSuite.swift    On-device Apple Intelligence test cases
└── SummarizerSkill.swift                      Skill fixture shared by both suites

Plugins/RunIntegrationTests/
└── RunIntegrationTestsPlugin.swift            SPM command plugin (verb: integration-tests)
```

---

## Adding a new test case

1. Open the suite file for the provider you want to test.
2. Add a private `async throws` method following the given / when / then pattern:

```swift
private func testMyFeature() async throws {
    // given
    let request = try AIRequestBuilder()
        .model(.claudeHaiku45)
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

Add a new `case` to the CLI switch in `IntegrationApp.swift`, guarded by the
provider's prerequisite (API key, device capability, etc.).
