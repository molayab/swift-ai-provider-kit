# Architecture

## Contents

- [Overview](#overview)
- [Module Structure](#module-structure)
- [Core Abstractions](#core-abstractions)
- [Request Lifecycle](#request-lifecycle)
- [Streaming Flow](#streaming-flow)
- [ClaudeProvider Internals](#claudeprovider-internals)
- [Adding a New Provider](#adding-a-new-provider)
- [Concurrency Model](#concurrency-model)
- [Logging Architecture](#logging-architecture)
- [Context Layer (Planned)](#context-layer-planned)

---

## Overview

AIProviderKit is a Swift package that provides a provider-agnostic abstraction layer for interacting with AI models. The package targets iOS 26+, macOS 26+, watchOS 11+, tvOS 26+, and visionOS 2+, built with Swift 6 and full strict concurrency compliance.

The package ships four library products today:

- **AIProviderKit** -- the core module containing protocols, models, builders, registries, and the `AIClient` actor. Zero external dependencies.
- **ClaudeProvider** -- the Anthropic Messages API implementation. Depends only on `AIProviderKit`.
- **OpenAIProvider** -- the OpenAI Chat Completions API implementation. Depends only on `AIProviderKit`.
- **AppleIntelligenceProvider** -- on-device inference via Apple Intelligence (iOS 26+ / macOS 26+). Depends only on `AIProviderKit`; requires the `FoundationModels` framework at runtime.

Persistence and context retrieval modules are planned for future milestones.

---

## Module Structure

```mermaid
graph LR
    App["Your App"]

    subgraph shipped["Shipped modules"]
        Core["AIProviderKit"]
        Claude["ClaudeProvider"]
        OpenAI["OpenAIProvider"]
        FM["AppleIntelligenceProvider"]
    end

    App --> Claude
    App --> OpenAI
    App --> FM
    App --> Core

    Claude --> Core
    OpenAI --> Core
    FM --> Core
```

---

## Core Abstractions

```mermaid
classDiagram
    class AIProvider {
        <<protocol>>
        +identifier: String
        +capabilities: Set~AICapability~
        +contextWindowSize: Int
        +send(AIRequest) AIResponse
    }

    class StreamableProvider {
        <<protocol>>
        +stream(AIRequest) AsyncThrowingStream
    }

    class ModelDiscoveryProvider {
        <<protocol>>
        +listModels() [AIModelInfo]
    }

    class AuthorizationProvider {
        <<protocol>>
        +authorizationHeaders() [String:String]
        +refresh()
    }

    class Skill {
        <<protocol>>
        +identifier: String
        +description: String
        +tools: [Tool]
        +recipe: Recipe?
        +process(AIResponse) SkillResult
    }

    class ToolGroup {
        <<protocol>>
        +all: [Tool]$
    }

    class AIClient {
        <<actor>>
        +toolRegistry: ToolRegistry
        +skillRegistry: SkillRegistry
        +recipeRegistry: RecipeRegistry
        +send(AIRequest) AIResponse
        +stream(AIRequest) AsyncThrowingStream
        +send(recipe:values:model:) AIResponse
        +execute(skillId:input:model:) SkillResult
    }

    AIProvider <|-- StreamableProvider
    AIProvider <|-- ModelDiscoveryProvider
    AIClient --> AIProvider
    AIClient --> ToolRegistry
    AIClient --> SkillRegistry
    AIClient --> RecipeRegistry
```

### Key types

| Type | Role |
|---|---|
| `AIClient` (actor) | Main entry point. Coordinates the provider, registries, and the automatic tool-execution loop. |
| `AIProvider` (protocol) | The single integration point for new AI backends. Requires `identifier`, `capabilities`, and `send(_:)`. |
| `StreamableProvider` (protocol) | Extends `AIProvider` with `stream(_:)` for server-sent event streaming. |
| `ModelDiscoveryProvider` (protocol) | Extends `AIProvider` with `listModels()` for runtime model enumeration. `OpenAIProvider` conforms; `ClaudeProvider` planned in 0.3.1. |
| `AIModelInfo` (struct) | Model metadata from `listModels()`: `model: AIModel`, `displayName: String?`, `createdAt: Date?`. |
| `AuthorizationProvider` (protocol) | Supplies HTTP authorization headers. Implementations include `APIKeyAuthorization` (x-api-key) and `BearerAuthorization` (Authorization: Bearer). |
| `ContentBlock` (enum) | Universal currency for message content: `.text`, `.image`, `.toolUse`, `.toolResult`. All providers map to/from this type. |
| `JSONValue` (enum) | Type-safe, `Sendable`, `Codable` representation of arbitrary JSON. Used for tool inputs and outputs, avoiding `Any`. |
| `Tool` (struct) | A callable tool with a name, description, `JSONSchema` input schema, and an async handler. |
| `Recipe` (struct) | A reusable prompt template with `{{placeholder}}` substitution. |
| `Skill` (protocol) | Bundles tools, an optional recipe, and post-processing logic into a reusable capability. |
| `ToolRegistry` (actor) | Thread-safe storage and lookup for `Tool` instances. Supports bulk registration via `ToolGroup`. |
| `SkillRegistry` (actor) | Thread-safe storage and lookup for `Skill` instances. |
| `RecipeRegistry` (actor) | Thread-safe storage and lookup for `Recipe` instances. |
| `AICapability` (enum) | Declares what a provider supports: `.text`, `.vision`, `.tools`, `.streaming`, `.systemPrompt`. |
| `AIRequestBuilder` (class) | Fluent builder for `AIRequest` with validation on `build()`. |
| `ContentBlockBuilder` | Result builder for constructing `[ContentBlock]` arrays declaratively. |
| `ConversationBuilder` | Result builder for constructing `[Message]` arrays declaratively. |

### Built-in tool groups

Three `ToolGroup`-conforming enums ship in `AIProviderKit`:

- `CalendarTool` -- `list_calendar_events`, `create_calendar_event` (EventKit)
- `RemindersTool` -- `list_reminders`, `create_reminder` (EventKit)
- `LocationTool` -- `get_current_location` (CoreLocation, with optional reverse geocoding)

---

## Request Lifecycle

When `AIClient.send(_:)` is called, the request flows through the provider and, if the model returns tool-use blocks, enters an automatic execution loop.

```mermaid
sequenceDiagram
    participant App
    participant AIClient
    participant Provider as AIProvider
    participant ToolRegistry

    App->>AIClient: send(request)
    AIClient->>Provider: send(request)
    Provider-->>AIClient: AIResponse (stopReason: toolUse)

    loop While response.requiresToolExecution
        AIClient->>ToolRegistry: execute(toolName, input) via TaskGroup
        ToolRegistry-->>AIClient: JSONValue result
        Note over AIClient: Appends assistant + toolResult messages
        AIClient->>Provider: send(followUpRequest)
        Provider-->>AIClient: AIResponse
    end

    AIClient-->>App: AIResponse (stopReason: endTurn)
```

Tool executions within a single turn run concurrently via `withThrowingTaskGroup`. The client constructs a follow-up request by appending the assistant's tool-use message and the user's tool-result message to the original conversation, preserving the full history.

---

## Streaming Flow

Streaming bypasses the automatic tool-execution loop. The caller receives raw `AIStreamEvent` values and is responsible for handling any tool-use turns manually.

```mermaid
sequenceDiagram
    participant App
    participant AIClient
    participant StreamableProvider

    App->>AIClient: stream(request)
    AIClient->>StreamableProvider: stream(request)
    loop SSE events
        StreamableProvider-->>App: AIStreamEvent.textDelta
    end
    StreamableProvider-->>App: AIStreamEvent.message (final)
```

If the provider does not conform to `StreamableProvider`, `AIClient.stream(_:)` returns a stream that immediately throws `AIError.providerUnsupported(capability: .streaming)`.

`AIStreamEvent` has three cases: `.textDelta(String)`, `.toolUseDelta(id:name:inputDelta:)`, and `.message(AIResponse)`.

---

## ClaudeProvider Internals

`ClaudeProvider` conforms to `StreamableProvider` and uses a mapper pattern to isolate the Anthropic-specific wire format from the core abstractions.

```mermaid
classDiagram
    class ClaudeProvider {
        +identifier: "claude"
        +capabilities: text, vision, tools, streaming, systemPrompt
        +send(AIRequest) AIResponse
        +stream(AIRequest) AsyncThrowingStream
    }

    class HTTPClient {
        <<protocol>>
        +send(HTTPRequest) HTTPResponse
        +stream(HTTPRequest) AsyncThrowingStream~Data~
    }

    class ClaudeRequestMapper {
        +map(AIRequest, stream: Bool) ClaudeRequest
    }

    class ClaudeResponseMapper {
        +map(ClaudeResponse) AIResponse
        +mapStreamEvent(Data) [AIStreamEvent]
    }

    class URLSessionHTTPClient {
        +send(HTTPRequest) HTTPResponse
        +stream(HTTPRequest) AsyncThrowingStream~Data~
    }

    class APIKeyAuthorization {
        +authorizationHeaders() [String:String]
    }

    HTTPClient <|-- URLSessionHTTPClient
    ClaudeProvider --> HTTPClient
    ClaudeProvider --> ClaudeRequestMapper
    ClaudeProvider --> ClaudeResponseMapper
    ClaudeProvider --> AuthorizationProvider
```

- **`ClaudeRequestMapper`** converts `AIRequest` into the `ClaudeRequest` Encodable struct, mapping `ContentBlock` to `ClaudeContentBlock`, `Tool` to `ClaudeTool`, and `Message` to `ClaudeMessage`. System prompts are extracted to the top-level `system` field per Anthropic's API format.
- **`ClaudeResponseMapper`** converts `ClaudeResponse` back to `AIResponse`, mapping content blocks and stop reasons. For streaming, it parses `content_block_delta` SSE events with `text_delta` type.
- **`HTTPClient`** is an internal protocol with `send` and `stream` methods. The production implementation (`URLSessionHTTPClient`) uses `URLSession`; tests inject `MockHTTPClient`.
- **`APIKeyAuthorization`** implements `AuthorizationProvider` by returning `["x-api-key": apiKey]`.

Model constants are defined as static extensions on `AIModel`: `.claudeOpus46`, `.claudeSonnet46`, `.claudeHaiku45`.

---

## OpenAIProvider Internals

`OpenAIProvider` conforms to `StreamableProvider` and `ModelDiscoveryProvider`, using the same mapper pattern as `ClaudeProvider`.

```mermaid
classDiagram
    class OpenAIProvider {
        +identifier: "openai"
        +capabilities: text, vision, tools, streaming, systemPrompt, modelDiscovery
        +send(AIRequest) AIResponse
        +stream(AIRequest) AsyncThrowingStream
        +listModels() [AIModelInfo]
    }

    class OpenAIRequestMapper {
        +map(AIRequest, stream: Bool) OpenAIChatRequest
    }

    class OpenAIResponseMapper {
        +map(OpenAIChatResponse) AIResponse
        +mapStreamEvent(Data) [AIStreamEvent]
    }

    class OpenAIConstants {
        +chatCompletionsURL: URL$
        +modelsURL: URL$
        +chatModelPrefixes: [String]$
        +excludedModelPrefixes: [String]$
    }

    class BearerAuthorization {
        +authorizationHeaders() [String:String]
    }

    OpenAIProvider --> HTTPClient
    OpenAIProvider --> OpenAIRequestMapper
    OpenAIProvider --> OpenAIResponseMapper
    OpenAIProvider --> AuthorizationProvider
    OpenAIProvider --> OpenAIConstants
    BearerAuthorization ..|> AuthorizationProvider
```

Key differences from `ClaudeProvider`:

| Concept | Claude | OpenAI |
|---------|--------|--------|
| Auth header | `x-api-key` | `Authorization: Bearer` |
| System prompt | Top-level `system` field | First `{"role":"system"}` message |
| Tool calls | `tool_use` content block | `tool_calls` array on assistant message |
| Tool results | `tool_result` content block | Individual `role: "tool"` messages |
| Images | `image` content block | `image_url` content part (URL or data URI) |
| Finish reason | `end_turn` / `tool_use` | `stop` / `tool_calls` |
| Usage fields | `input_tokens` / `output_tokens` | `prompt_tokens` / `completion_tokens` |

`OpenAIConstants` centralises all endpoint URLs, chat-model prefixes, and exclusion lists. Adding a new model family (e.g., `gpt-5`) requires only updating `chatModelPrefixes` in that file.

---

## Adding a New Provider

To add a new AI provider (e.g., OpenAI), follow this checklist:

1. Add a new library target in `Package.swift` with a dependency on `AIProviderKit`.
2. Create a folder under `Sources/` (e.g., `Sources/OpenAIProvider/`).
3. Implement the mapper pair:
   - `XRequestMapper` -- converts `AIRequest` to the provider's wire format.
   - `XResponseMapper` -- converts the provider's response to `AIResponse` and `AIStreamEvent`.
4. Implement `HTTPClient` (or reuse `URLSessionHTTPClient` if the wire protocol is standard REST/SSE).
5. Create the provider class conforming to `AIProvider` (or `StreamableProvider` if streaming is supported).
6. Extend `AIModel` with provider-specific model constants (e.g., `.gpt4o`).
7. No changes to `AIClient` or any core type are required.

See [`Documentation/AddingAProvider.md`](AddingAProvider.md) for a full walkthrough.

---

## Concurrency Model

The package uses Swift 6 strict concurrency throughout. Both `StrictConcurrency` and `ExistentialAny` upcoming features are enabled on all targets.

**Actors** provide thread-safe mutable state:
- `AIClient` is an actor. All public methods (`send`, `stream`, `execute`) are isolated to the actor.
- `ToolRegistry`, `SkillRegistry`, and `RecipeRegistry` are actors. Registration and lookup operations are actor-isolated.

**Sendable compliance** is enforced across all public types:
- All model types (`AIRequest`, `AIResponse`, `ContentBlock`, `JSONValue`, `Tool`, `Recipe`, `Message`, `TokenUsage`, `StopReason`, `AICapability`, `AIModel`, `SkillResult`, `AILogEntry`, `AILogLevel`) are `Sendable` value types.
- Protocols (`AIProvider`, `StreamableProvider`, `AuthorizationProvider`, `Skill`) require `Sendable` conformance.
- `Tool.handler` is typed as `@Sendable (JSONValue) async throws -> JSONValue`.
- `ClaudeProvider` is a `final class` (not an actor) because it holds only `Sendable` dependencies and performs no mutable state changes after initialization.
- `URLSessionHTTPClient` is `@unchecked Sendable` because `URLSession` predates Swift concurrency.

**Structured concurrency** is used for parallel tool execution: `AIClient.executeTools` uses `withThrowingTaskGroup` to run all tool calls from a single model turn concurrently.

**MainActor isolation**: `AILogStore` is `@MainActor`-isolated and uses `@Observable` for SwiftUI reactivity. `AILogger` forwards entries to `AILogStore.shared` via `Task { @MainActor in ... }`.

---

## Context Layer — AIProviderKitContext

> Planned for milestones 0.6.0 – 0.6.7. See [`Documentation/Issues/context-retrieval.md`](Issues/context-retrieval.md) for the full design.

```mermaid
graph TD
    FC["FolderContext (actor)\nHigh-level entry point"]
    FI["FolderIndexer (actor)\nscan → parse → chunk → embed → store"]
    DP["DocumentParser (protocol)\nTextDocumentParser · PDFDocumentParser"]
    DC["DocumentChunker\nchunkSize + overlap · ChunkSource"]
    EP["EmbeddingProvider (protocol)\nVoyage · OpenAI · NLEmbedding"]
    VS["VectorStore (protocol)\nInMemoryVectorStore"]
    RC["RetrievalContext\n[ScoredChunk] ready for injection"]
    RB["AIRequestBuilder\n.context(RetrievalContext)"]
    AI["AIClient\n.send / .stream"]

    FC -->|owns| FI
    FI -->|uses| DP
    FI -->|uses| DC
    FI -->|uses| EP
    FI -->|stores in| VS
    VS -->|search result| RC
    FC -->|returns| RC
    RC -->|injected via| RB
    RB -->|builds AIRequest for| AI
```

### Context Retrieval Flow

```mermaid
sequenceDiagram
    participant App
    participant FolderContext
    participant EmbeddingProvider
    participant VectorStore
    participant AIRequestBuilder
    participant AIClient

    App->>FolderContext: init(url:embeddingProvider:options:)
    Note over FolderContext: Indexes folder on init (async)
    App->>FolderContext: retrieve(for: query)
    FolderContext->>EmbeddingProvider: embed([query])
    EmbeddingProvider-->>FolderContext: [[Float]]
    FolderContext->>VectorStore: search(query:topK:)
    VectorStore-->>FolderContext: [ScoredChunk]
    FolderContext-->>App: RetrievalContext
    App->>AIRequestBuilder: .context(retrievalContext)
    App->>AIRequestBuilder: .addMessage(.user(text: query))
    App->>AIClient: send(request)
    AIClient-->>App: AIResponse
```

---

## Logging Architecture

```mermaid
graph LR
    Code["Any module code"]
    Logger["AILogger\n(os.Logger wrapper)"]
    OSLog["System Log\n(Console.app)"]
    Store["AILogStore\n(@Observable, @MainActor)"]
    View["AILogView\n(SwiftUI, AIProviderKitUI)"]

    Code -->|info/warning/error| Logger
    Logger --> OSLog
    Logger -->|optional forwarding| Store
    Store --> View
```

`AILogger` is a lightweight `Sendable` struct that wraps `os.Logger`. It writes to the system log unconditionally and optionally forwards entries to `AILogStore.shared` for in-app display. `AILogStore` is `@Observable` and `@MainActor`-isolated, enabling `AILogView` to react to new entries automatically. The store caps entries at `maximumEntries` (default 1,000), evicting the oldest first.

---

## Context Layer (Planned)

> **Status:** Not yet implemented. Planned for a future milestone. See [`Documentation/Issues/context-retrieval.md`](Issues/context-retrieval.md) for the full design.

The Context layer will introduce a new module (`AIProviderKitContext`) for augmenting model requests with relevant chunks retrieved from local document folders. The planned design includes:

- **`FolderContext`** (actor) -- high-level entry point for indexing and retrieval
- **`FolderIndexer`** (actor) -- scan, parse, chunk, embed, store pipeline
- **`DocumentParser`** (protocol) -- extensible document parsing (`TextDocumentParser`, `PDFDocumentParser`)
- **`DocumentChunker`** -- configurable chunk size and overlap
- **`EmbeddingProvider`** (protocol) -- pluggable embeddings (Voyage, OpenAI, NLEmbedding)
- **`VectorStore`** (protocol) -- pluggable vector storage (`InMemoryVectorStore`)
- **`RetrievalContext`** -- scored chunks ready for injection into `AIRequestBuilder`

```mermaid
graph TD
    FC["FolderContext (actor)"]
    FI["FolderIndexer (actor)"]
    DP["DocumentParser (protocol)"]
    DC["DocumentChunker"]
    EP["EmbeddingProvider (protocol)"]
    VS["VectorStore (protocol)"]
    RC["RetrievalContext"]
    RB["AIRequestBuilder"]

    FC -->|owns| FI
    FI -->|uses| DP
    FI -->|uses| DC
    FI -->|uses| EP
    FI -->|stores in| VS
    VS -->|search result| RC
    FC -->|returns| RC
    RC -->|injected via| RB
```
