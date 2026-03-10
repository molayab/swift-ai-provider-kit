# Architecture

## Package Structure

```
AIProviderKit (core)
└── ClaudeProvider
└── AIProviderKitUI

Tests
├── AIProviderKitTests
└── ClaudeProviderTests
```

---

## Module Dependency Graph

```mermaid
graph TD
    App["Your App"]
    UI["AIProviderKitUI"]
    Core["AIProviderKit"]
    Claude["ClaudeProvider"]

    App --> Core
    App --> Claude
    App --> UI
    Claude --> Core
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
