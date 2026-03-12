# Architecture

## Contents

- [Package Structure](#package-structure)
- [Module Dependency Graph](#module-dependency-graph)
- [Core Layer — AIProviderKit](#core-layer--aiproviderkitkit)
- [Request / Response Flow](#request--response-flow)
- [Streaming Flow](#streaming-flow)
- [ClaudeProvider Internals](#claudeprovider-internals)
- [Context Layer — AIProviderKitContext](#context-layer--aiproviderkitcontext)
- [Logging Architecture](#logging-architecture)

---

## Package Structure

```mermaid
graph TD
    subgraph Core
        AIProviderKit["AIProviderKit\n(zero external dependencies)"]
    end

    subgraph Providers
        Claude["ClaudeProvider"]
        OpenAI["OpenAIProvider *(0.3.0)*"]
        FM["FoundationModelProvider *(0.2.0)*"]
    end

    subgraph Persistence
        PFS["AIProviderKitPersistenceFS *(0.5.0)*"]
        PDB["AIProviderKitPersistenceDB *(0.6.0)*"]
    end

    subgraph Context["Context Retrieval"]
        CTX["AIProviderKitContext *(0.7.0)*"]
    end

    subgraph UI
        AKUI["AIProviderKitUI"]
    end

    Claude --> AIProviderKit
    OpenAI --> AIProviderKit
    FM --> AIProviderKit
    PFS --> AIProviderKit
    PDB --> AIProviderKit
    CTX --> AIProviderKit
    AKUI --> AIProviderKit
```

---

## Module Dependency Graph

```mermaid
graph LR
    App["Your App"]

    subgraph optional["Optional modules (import as needed)"]
        Claude["ClaudeProvider"]
        OpenAI["OpenAIProvider"]
        FM["FoundationModelProvider"]
        PFS["AIProviderKitPersistenceFS"]
        PDB["AIProviderKitPersistenceDB"]
        CTX["AIProviderKitContext"]
        UI["AIProviderKitUI"]
    end

    Core["AIProviderKit (core)"]

    App --> Claude
    App --> OpenAI
    App --> FM
    App --> PFS
    App --> PDB
    App --> CTX
    App --> UI
    App --> Core

    Claude --> Core
    OpenAI --> Core
    FM --> Core
    PFS --> Core
    PDB --> Core
    CTX --> Core
    UI --> Core
```

---

## Core Layer — AIProviderKit

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

    class AuthorizationProvider {
        <<protocol>>
        +authorizationHeaders() [String:String]
        +refresh()
    }

    class Skill {
        <<protocol>>
        +identifier: String
        +tools: [Tool]
        +recipe: Recipe?
        +process(AIResponse) SkillResult
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
    AIClient --> AIProvider
    AIClient --> ToolRegistry
    AIClient --> SkillRegistry
    AIClient --> RecipeRegistry
```

---

## Request / Response Flow

```mermaid
sequenceDiagram
    participant App
    participant AIClient
    participant Provider as AIProvider
    participant ToolRegistry

    App->>AIClient: send(request)
    AIClient->>Provider: send(request)
    Provider-->>AIClient: AIResponse (stopReason: toolUse)
    AIClient->>ToolRegistry: execute(toolName, input)
    ToolRegistry-->>AIClient: JSONValue result
    AIClient->>Provider: send(followUpRequest)
    Provider-->>AIClient: AIResponse (stopReason: endTurn)
    AIClient-->>App: AIResponse
```

---

## Streaming Flow

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

---

## ClaudeProvider Internals

```mermaid
classDiagram
    class ClaudeProvider {
        +identifier: "claude"
        +send(AIRequest) AIResponse
        +stream(AIRequest) AsyncThrowingStream
    }

    class HTTPClient {
        <<protocol>>
        +send(HTTPRequest) HTTPResponse
        +stream(HTTPRequest) AsyncThrowingStream~Data~
    }

    class ClaudeRequestMapper {
        +map(AIRequest, stream) ClaudeRequest
    }

    class ClaudeResponseMapper {
        +map(ClaudeResponse) AIResponse
        +mapStreamEvent(Data) AIStreamEvent?
    }

    class URLSessionHTTPClient {
        +send(HTTPRequest) HTTPResponse
        +stream(HTTPRequest) AsyncThrowingStream~Data~
    }

    HTTPClient <|-- URLSessionHTTPClient
    ClaudeProvider --> HTTPClient
    ClaudeProvider --> ClaudeRequestMapper
    ClaudeProvider --> ClaudeResponseMapper
```

---

## Context Layer — AIProviderKitContext

> Planned for milestones 0.7.0 – 0.7.7. See [`Documentation/Issues/context-retrieval.md`](Issues/context-retrieval.md) for the full design.

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
    Logger["AILogger\n(os.Logger)"]
    OSLog["System Log\n(Console.app)"]
    Store["AILogStore\n(@Observable)"]
    View["AILogView\n(SwiftUI)"]

    Code -->|info/warning/error| Logger
    Logger --> OSLog
    Logger -->|optional forwarding| Store
    Store --> View
```
