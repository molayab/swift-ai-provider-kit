# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build all targets
swift build

# Run all tests (mocked — no API key required)
swift test

# Run a specific test target
swift test --filter AIProviderKitTests
swift test --filter ClaudeProviderTests

# Run a single test by name
swift test --filter AIClientTests/sendForwardsRequest

# Run integration tests against the real Claude API (requires ANTHROPIC_API_KEY)
ANTHROPIC_API_KEY=sk-ant-... swift package integration-tests
```

## Architecture

This is a Swift Package with three library products:

- **`AIProviderKit`** — Core protocols, models, builders, registries, and the `AIClient` actor. Has no external dependencies.
- **`ClaudeProvider`** — Anthropic Messages API implementation. Depends on `AIProviderKit`.
- **`AIProviderKitUI`** — Optional SwiftUI `AILogView` for in-app log viewing. Depends on `AIProviderKit`.

### Key design patterns

**`AIClient` (actor)** is the main entry point. It owns a `ToolRegistry`, `SkillRegistry`, and `RecipeRegistry` (all `actor`-based). When `send(_:)` is called and the model returns a `toolUse` stop reason, `AIClient` executes the tools concurrently via `withThrowingTaskGroup` and sends a follow-up request automatically — this loop repeats until the model stops requesting tools.

**`AIProvider` protocol** is the only integration point for new providers. Implement `send(_:)` for request/response and optionally `StreamableProvider` for SSE streaming. No changes to `AIClient` or any core type are needed.

**`ClaudeProvider` internals** follow a mapper pattern:
- `ClaudeRequestMapper` — converts `AIRequest` → Claude-specific request body
- `ClaudeResponseMapper` — converts Claude response / SSE data → `AIResponse` / `AIStreamEvent`
- `HTTPClient` protocol (implemented by `URLSessionHTTPClient`) is injected, enabling test substitution via `MockHTTPClient`

**`ContentBlock`** is the universal currency for message content (`.text`, `.image`, `.toolUse`, `.toolResult`). All providers map to/from this type.

**`JSONValue`** is the untyped value type used for tool inputs/outputs, avoiding `Any`.

### Adding a new provider

1. Add a library + target in `Package.swift` (see commented-out OpenAI entries as a template)
2. Create a folder under `Sources/` with a mapper pair (`XRequestMapper`, `XResponseMapper`), an `HTTPClient` implementation, and the provider class conforming to `StreamableProvider`
3. Extend `AIModel` with provider-specific model constants
4. See `Documentation/AddingAProvider.md` for a full walkthrough

### Testing conventions

Tests use Swift Testing (`@Suite`, `@Test`, `#expect`). Each test follows **given / when / then** with comments. Mocks live in `Tests/<Target>/Mocks/`:
- `MockAIProvider` — configurable stub that records received requests
- `SequentialMockProvider` — returns a queue of pre-configured responses (used for multi-turn tool-use tests)
- `MockHTTPClient` — stubs HTTP at the network layer for `ClaudeProvider` tests

### Platform & language requirements

- Swift 6, full `Sendable` compliance, `StrictConcurrency` and `ExistentialAny` upcoming features enabled on all targets
- iOS 26+ / macOS 13+ / watchOS 11+ / tvOS 26+ / visionOS 2+
- Use `async/await` and actors throughout; avoid callback-based or GCD patterns

## Documentation assets

`Documentation/Assets/banner.svg` — 900×240 px dark-theme banner. Key colors to keep consistent:

| Role | Hex |
|---|---|
| Background | `#111114` → `#1A1A1F` gradient |
| Swift orange accent | `#F05138` → `#C73E29` |
| Primary text | `#FFFFFF` |
| Body / tagline text | `#D0D0D8` |
| Muted labels | `#7A7A82` |
| Coming-soon labels | `#666670` |
| Active provider (Claude) label | `#F0D090` (warm gold), stroke `#D97706` |
| Streaming badge | `#3FA0FF` |
| Tools badge | `#4CD964` |
| Skills badge | `#FFB830` |

Provider box labels: "Claude", "OpenAI", "Foundation Models" (no "Provider" suffix).
