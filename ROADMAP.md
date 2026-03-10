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

## 0.4.0 — Persistence: Core Protocol & In-Memory

Establishes the persistence contract and a zero-dependency default backend.
All higher-level `AIClient` APIs are introduced here; later versions swap
only the storage backend.

- [ ] `ConversationStore` protocol — provider-agnostic async CRUD for conversations and turns
- [ ] `Conversation` / `ConversationTurn` models — codable, identifiable, timestamped
- [ ] `InMemoryConversationStore` — default backend, non-persistent, zero dependencies
- [ ] `AIClient` integration — `send(conversationId:message:model:)` overload that auto-loads and auto-saves turns
- [ ] Conversation management API — list, load, delete, archive
- [ ] Token-budget trimming strategy — prune oldest turns when context limit is approached
- [ ] Unit tests — full coverage via `InMemoryConversationStore`

---

## 0.5.0 — Persistence: File System Backend

Maximum compatibility — works on all Apple platforms and Linux without
additional frameworks. Ships as a separate optional library product
(`AIProviderKitPersistenceFS`).

- [ ] `FileSystemConversationStore` — stores each conversation as a JSON file under a configurable directory
- [ ] Atomic writes — write to temp file, rename on success, no partial-write corruption
- [ ] Async I/O — file operations via `AsyncStream` / task offloading, never blocks the caller
- [ ] Conversation index file — fast list/search without loading all turn files
- [ ] Import / export — read and write portable conversation JSON bundles
- [ ] Unit tests — `tmp`-directory fixtures, cross-platform
- [ ] Integration tests — round-trip verify against real Claude responses

---

## 0.6.0 — Persistence: Database Backend

SwiftData-backed store for apps that need querying, indexing, or
multi-process access. Ships as a separate optional library product
(`AIProviderKitPersistenceDB`).

- [ ] `SwiftDataConversationStore` — full SwiftData (`@Model`) implementation (iOS 17+ / macOS 14+)
- [ ] Schema migrations — versioned `ModelContainer` configuration
- [ ] Predicate-based search — query conversations by date, provider, model, metadata
- [ ] `AIProviderKitUI` — conversation history list view backed by `@Query`
- [ ] Unit tests — in-memory `ModelContainer` for test isolation
- [ ] Migration utilities — import `FileSystemConversationStore` data into SwiftData

---

## 1.0.0 — MVP

All of 0.2–0.6, plus:

- [ ] Stable public API guarantee (SemVer from this point forward)
- [ ] Comprehensive DocC documentation for all public symbols
- [ ] Token-counting helpers per provider
- [ ] Full test coverage report ≥ 85 %
- [ ] Example app (SwiftUI) demonstrating all three providers + both persistence backends

---

## Beyond 1.0.0 (ideas, not committed)

- Anthropic extended thinking / reasoning steps
- OpenAI Assistants API (thread + file management)
- Retrieval-Augmented Generation (RAG) helpers
- Prompt caching support (Anthropic / OpenAI)
- Webhook / push notification integration for long-running requests
- Android / Linux support (swift-foundation)
