# Context Layer — Provider Viability Investigation

## Contents

- [Summary](#summary)
- [Per-Provider Analysis](#per-provider-analysis)
  - [Anthropic Claude](#anthropic-claude)
  - [OpenAI](#openai)
  - [Apple Foundation Models](#apple-foundation-models-on-device)
- [Cross-Provider Comparison](#cross-provider-comparison)
- [Proposed Architecture](#proposed-architecture)
- [Open Questions](#open-questions)
- [References](#references)

---

> **Date:** 2026-03-10
> **Status:** Accepted — scheduled for milestones 0.7.0 – 0.7.7
> **Scope:** Feasibility of a provider-agnostic context retrieval layer (`AIProviderKitContext`) across all three MVP providers

---

## Summary

All three MVP providers can participate in a context retrieval workflow, but the embedding source,
managed-retrieval options, and token budgets differ significantly. A shared
`EmbeddingProvider` protocol + `RetrievalContext` value type covers the common path;
provider-specific overrides handle managed server-side retrieval (OpenAI) and
on-device embedding (Foundation Models).

---

## Per-Provider Analysis

### Anthropic Claude

| Concern | Detail |
|---|---|
| Embedding source | **External** — Voyage AI (separate API key). Recommended models: `voyage-3-large` (1 024-dim, 32K context), `voyage-3.5`, `voyage-3.5-lite` |
| Managed server-side retrieval | **No.** The Files API (beta) uploads files once and injects them by `file_id`, but the full file lands in the context window as tokens — no chunking or vector ranking on Anthropic's side |
| Context budget for retrieval | 200K tokens standard; 1M token beta window (`anthropic-beta: context-1m-2025-08-07`, tier 4+) |
| Streaming + context retrieval | Yes — SSE streaming is independent of how context was fetched or injected |
| Additional API key needed | Yes — Voyage AI key on top of the Anthropic key |

**Design notes:**
- A `VoyageEmbeddingProvider` (or generic `EmbeddingProvider` protocol conformance) is the only embedding path.
- Retrieved chunks become `.text` `ContentBlock` items injected into `messages` — no changes to `AIRequest` structure.
- Files API support (content-stuffing shortcut) would need a `ContentBlock.document(fileId:)` variant and beta-header injection in `ClaudeProvider`.

---

### OpenAI

| Concern | Detail |
|---|---|
| Embedding source | **First-party** — `/v1/embeddings` endpoint. `text-embedding-3-large` (3 072-dim), `text-embedding-3-small` (1 536-dim). Both support Matryoshka dimension reduction |
| Managed server-side retrieval | **Yes** — `file_search` tool in the Responses API. Auto-chunks uploads (~800 tokens, 400-token overlap), runs hybrid vector + BM25 search. Pricing: $2.50/1K queries, $0.10/GB/day (1 GB free) |
| Context budget for retrieval | GPT-4o / o1: 128K; o3-mini: 200K; GPT-4.1: 1M |
| Streaming + context retrieval | Yes — streaming and `file_search` are fully compatible |
| Additional API key needed | No — same OpenAI key |

**Design notes:**
- `OpenAIEmbeddingProvider` conforms to `EmbeddingProvider` — no third-party dependency.
- Two context retrieval modes:
  - **DIY** — call Embeddings API, inject retrieved chunks as message content (same path as Claude).
  - **Managed** — pass `file_search` as a `Tool` variant in the request; OpenAI handles retrieval server-side.
- The managed path requires a new `Tool.fileSearch(vectorStoreIds:)` case or a provider-specific request overlay.
- The Assistants API (which also had file search) is being deprecated mid-2026; Responses API is the successor.

---

### Apple Foundation Models (on-device)

| Concern | Detail |
|---|---|
| Embedding source | **On-device** — `NLEmbedding` (NaturalLanguage framework) or a bundled Core ML sentence transformer. No embedding surface in the Foundation Models framework itself |
| Managed server-side retrieval | **No** — entirely client-side; no file storage or retrieval API |
| Context budget for retrieval | **~3K tokens usable** (4K hard total including system prompt, tools, response) |
| Streaming + context retrieval | Yes — `AsyncSequence` streaming is independent of pre-fetched context |
| Additional API key needed | No |

**Design notes:**
- Requires a fully client-side pipeline: chunk at build/fetch time → embed on-device → cosine nearest-neighbor → inject single best chunk.
- The 4K budget enforces a "one chunk max" retrieval strategy; precision matters far more than recall.
- A `contextWindowSize: Int` property on `AIProvider` would let the context layer auto-truncate to the budget.
- Only available on Apple Intelligence-capable hardware (A17 Pro / M-series, Apple Intelligence enabled).

---

## Cross-Provider Comparison

| Concern | Claude | OpenAI | Foundation Models |
|---|---|---|---|
| Embedding source | External (Voyage AI) | First-party API | On-device (NLEmbedding / Core ML) |
| Managed server-side retrieval | No | Yes (`file_search`) | No |
| Context budget | 200K / 1M (beta) | 128K – 1M | ~3K usable |
| Streaming + context retrieval | ✓ | ✓ | ✓ |
| Extra API key for embeddings | Yes | No | No |

---

## Proposed Architecture

### New protocols / types

```swift
// Protocol — any embedding backend conforms to this
public protocol EmbeddingProvider: Sendable {
    func embed(_ texts: [String]) async throws -> [[Float]]
}

// Provider implementations
public struct VoyageEmbeddingProvider: EmbeddingProvider { … }   // Claude stack
public struct OpenAIEmbeddingProvider: EmbeddingProvider { … }   // OpenAI stack
public struct NLEmbeddingProvider: EmbeddingProvider { … }        // On-device

// Value type — carries retrieved chunks ready for injection
public struct RetrievalContext: Sendable {
    public let chunks: [String]
    public let scores: [Float]
}

// AIProvider extension — surfaces token budget for retrieval sizing
public protocol AIProvider {
    // … existing surface …
    var contextWindowSize: Int { get }   // new
}
```

### Context retrieval flow (all providers, DIY path)

```
1. Chunk documents (at app build time or lazily at runtime)
2. Embed chunks → EmbeddingProvider.embed(_:)
3. Store vectors (in-memory, SQLite + sqlite-vec, or Core Data)
4. At query time: embed user message → nearest-neighbor search → RetrievalContext
5. Inject RetrievalContext.chunks as ContentBlock.text items into AIRequest
6. Send / stream via AIClient as normal
```

### OpenAI managed path (shortcut)

```swift
// Pass file_search as a tool — OpenAI handles steps 1-4 server-side
let request = try AIRequestBuilder()
    .model(.gpt4o)
    .tools([.fileSearch(vectorStoreIds: ["vs_abc123"])])
    .addMessage(.user(text: query))
    .build()
```

---

## Open Questions

- Should `EmbeddingProvider` live in `AIProviderKit` core (adding a dependency boundary) or in a new `AIProviderKitContext` library product?
- Vector store backend: in-memory only for 0.7.0, or ship a SQLite adapter from day one?
- Token budget property: hard-code per model or let the provider report it dynamically?
- Should `RetrievalContext` be injected automatically by `AIClient` (if one is registered) or always manually by the caller?

---

## References

- [Anthropic Files API](https://platform.claude.com/docs/en/docs/build-with-claude/files)
- [Anthropic Claude Models Overview](https://platform.claude.com/docs/en/about-claude/models/overview)
- [Anthropic Embeddings (Voyage AI)](https://platform.claude.com/docs/en/build-with-claude/embeddings)
- [OpenAI File Search / Responses API](https://cookbook.openai.com/examples/file_search_responses)
- [OpenAI New Tools for Building Agents](https://openai.com/index/new-tools-for-building-agents/)
- [Apple TN3193: Managing context window](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)
- [Apple Foundation Models 2025 Updates](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)
- [OpenAI GPT-4.1 model docs](https://platform.openai.com/docs/models/gpt-4.1)
