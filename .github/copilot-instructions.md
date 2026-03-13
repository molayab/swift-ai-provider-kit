# AIProviderKit — Copilot Code Review Instructions

## Project Overview

AIProviderKit is a Swift 6 package providing a provider-agnostic abstraction layer for AI models. Three shipped modules: `AIProviderKit` (core, zero deps), `ClaudeProvider` (Anthropic), `AppleIntelligenceProvider` (on-device). Swift 6 strict concurrency with full `Sendable` compliance throughout.

---

## Swift & Concurrency

- Enforce Swift 6 strict concurrency. Every type crossing actor boundaries must be `Sendable`.
- Use `actor` for all mutable shared state. Prefer `actor` over `class` + locks.
- Use `async/await` and structured concurrency (`withThrowingTaskGroup`). Flag any GCD, `DispatchQueue`, or callback-based patterns.
- `final class` is acceptable only when the type holds exclusively `Sendable` dependencies and has no mutable state after init.
- `@unchecked Sendable` must have an accompanying comment explaining why it is safe.
- Flag `nonisolated` on actor methods unless the method only reads `let` properties.

---

## Architecture Rules

- `AIClient` is the only coordinator. No new type should import details of a specific provider.
- New providers must conform to `AIProvider` (or `AIStreamableProvider` for streaming support). No changes to `AIClient` or core types are required or acceptable.
- Every provider must follow the mapper pattern: a dedicated `XRequestMapper` and `XResponseMapper`. No mapping logic inside the provider class itself.
- `ContentBlock` is the universal content currency. Providers must map to/from it; they must not leak provider-specific types into `AIProviderKit`.
- `JSONValue` is the required type for all tool inputs and outputs. Flag any use of `Any`, `[String: Any]`, or `AnyCodable`.
- Registries (`ToolRegistry`, `SkillRegistry`, `RecipeRegistry`) are actors. Access must be `await`ed; never store a registry reference outside an actor context.

---

## Code Style

- Prefer value types (`struct`, `enum`) over reference types unless actor semantics or identity are required.
- Avoid force unwraps (`!`) and `try!`. Use `guard let` or propagate errors.
- Errors must conform to the project's `AIError` type or a clearly named domain error. Avoid bare `throw NSError(...)`.
- No magic strings or numbers. Constants belong in extensions or enums.
- File names must match the primary type they define (e.g., `ClaudeRequestMapper.swift`).

---

## Testing

- Tests use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`). Flag any use of XCTest.
- All tests follow **given / when / then** with section comments.
- Mocks live in `Tests/<Target>/Mocks/`. No inline ad-hoc stubs.
- Provider tests must inject `MockHTTPClient` — never hit real network endpoints.
- `AIClient` tests use `MockAIProvider` or `SequentialMockProvider` for multi-turn scenarios.
- Integration tests (under `Sources/IntegrationTests/`) require `ANTHROPIC_API_KEY` and are opt-in only.

---

## Documentation

- Diagrams use Mermaid only (`graph`, `sequenceDiagram`, `flowchart`). Flag ASCII art diagrams.
- Public API additions require a corresponding entry in `Documentation/Architecture.md` or `Documentation/UseCases.md`.
- New provider walkthroughs go in `Documentation/AddingAProvider.md`.

---

## Security

- API keys must never be hardcoded. Use `AuthorizationProvider` injection.
- Flag any `print()` or `NSLog()` calls that could leak tokens or user data. Use `AILogger` instead.
- HTTP requests must go through `HTTPClient` protocol — never call `URLSession` directly in provider or mapper code.
