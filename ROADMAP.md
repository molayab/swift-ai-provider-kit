# Roadmap

This document tracks planned milestones toward the **1.0.0 MVP** release.
Each version is a git tag consumable via Swift Package Manager.

---

## 0.1.0 — Initial Demo ✅ (current)

Foundation and Claude provider. Public API is considered stable enough for
early adopters; minor breaking changes may still occur before 1.0.0.

- [x] `AIProviderKit` core — protocols, models, builders, registries, `AIClient`
- [x] `ClaudeProvider` — Anthropic Messages API (text, vision, tools, streaming)
- [x] Automatic tool-execution loop in `AIClient.send(_:)`
- [x] SSE streaming via `AsyncThrowingStream`
- [x] Recipes (`{{placeholder}}` prompt templates)
- [x] Skills (tool bundle + recipe + post-processing)
- [x] Thread-safe actor-based registries (tools, skills, recipes)
- [x] `AILogger` + `AILogStore` structured logging
- [x] `AIProviderKitUI` — SwiftUI `AILogView`
- [x] Predefined tools — `LocationTool`, `CalendarTool`, `RemindersTool`
- [x] Unit tests — 194 tests, fully mocked (no API key required)
- [x] Integration tests — `swift package integration-tests` against real Claude API
- [x] Swift 6 — full `Sendable` compliance, `StrictConcurrency`, `ExistentialAny`

---

## 0.2.0 — OpenAI Provider

- [ ] `OpenAIProvider` — Chat Completions API (text, vision, tools, streaming)
- [ ] `AIModel` constants — `gpt-4o`, `gpt-4o-mini`, `o1`, `o3-mini`
- [ ] Map OpenAI function-calling to `ContentBlock.toolUse` / `toolResult`
- [ ] Unit tests — `MockHTTPClient` pattern mirroring `ClaudeProviderTests`
- [ ] Integration tests — `swift package integration-tests` extended for OpenAI

---

## 0.3.0 — Apple Foundation Models Provider

- [ ] `FoundationModelProvider` — on-device inference via `FoundationModels` framework (iOS 26+ / macOS 26+)
- [ ] Platform guard — graceful capability check at runtime
- [ ] Streaming via `AsyncThrowingStream` wrapping the on-device stream
- [ ] Tool use mapping to Foundation Models function-calling API
- [ ] Unit + integration tests (simulator + device)

---

## 0.4.0 — Persistence Layer

- [ ] `ConversationStore` protocol — provider-agnostic conversation persistence
- [ ] `InMemoryConversationStore` — default, non-persistent (replaces ad-hoc message arrays)
- [ ] `SwiftDataConversationStore` — optional, backed by SwiftData (iOS 17+ / macOS 14+)
- [ ] `AIClient` integration — `send(conversationId:message:model:)` overload that auto-loads and auto-saves turns
- [ ] Conversation management API — list, load, delete, archive conversations
- [ ] Token-budget trimming strategy — prune oldest turns when context limit is approached
- [ ] Migration utilities — import/export conversation JSON

---

## 1.0.0 — MVP

All of 0.2–0.4, plus:

- [ ] Stable public API guarantee (SemVer from this point forward)
- [ ] Comprehensive DocC documentation for all public symbols
- [ ] Token-counting helpers per provider
- [ ] `AIProviderKitUI` — conversation history view component
- [ ] Full test coverage report ≥ 85 %
- [ ] Example app (SwiftUI) demonstrating all three providers + persistence

---

## Beyond 1.0.0 (ideas, not committed)

- Anthropic extended thinking / reasoning steps
- OpenAI Assistants API (thread + file management)
- Retrieval-Augmented Generation (RAG) helpers
- Prompt caching support (Anthropic / OpenAI)
- Webhook / push notification integration for long-running requests
- Android / Linux support (swift-foundation)
