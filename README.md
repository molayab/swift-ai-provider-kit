<p align="center">
  <img src="Documentation/Assets/banner.svg" alt="AIProviderKit" width="100%"/>
</p>

<p align="center">
  <a href="https://github.com/molayab/swift-ai-provider-kit/actions/workflows/ci.yml"><img src="https://github.com/molayab/swift-ai-provider-kit/actions/workflows/ci.yml/badge.svg" alt="Tests"/></a>
  <img src="https://img.shields.io/badge/Swift-6.2-orange?logo=swift&logoColor=white" alt="Swift 6"/>
  <img src="https://img.shields.io/badge/Platforms-iOS%2026%20%7C%20macOS%2026%20%7C%20watchOS%2011%20%7C%20tvOS%2026%20%7C%20visionOS%202-blue" alt="Platforms"/>
</p>

A modular Swift package for integrating AI providers in a provider-agnostic way. Swap between Claude, OpenAI, or on-device models without changing application code, with built-in streaming, automatic tool execution, reusable prompt templates, and composable skills.

Built with Swift 6, full `Sendable` compliance, and SOLID principles throughout.

---

## Features

| Feature | Description |
|---|---|
| **Provider abstraction** | Swap providers without changing application code |
| **Automatic tool execution** | The client executes tool calls and follows up automatically |
| **Streaming** | Server-sent event streaming via `AsyncThrowingStream` |
| **Recipes** | Reusable `{{placeholder}}` prompt templates |
| **Skills** | Composable capabilities (tools + recipe + post-processing) |
| **Registries** | Thread-safe `actor`-based stores for tools, skills, and recipes |
| **Structured logging** | `os.Logger`-backed `AILogger` with optional in-app `AILogView` |
| **Predefined tools** | Location, Calendar, and Reminders tools ready to use |

---

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/molayab/swift-ai-provider-kit.git", from: "0.1.0")
]
```

Add the products you need:

```swift
.product(name: "AIProviderKit",   package: "AIProviderKit"),   // Core
.product(name: "ClaudeProvider",  package: "AIProviderKit"),   // Claude (Anthropic)
.product(name: "AIProviderKitUI", package: "AIProviderKit"),   // SwiftUI log viewer (optional)
```

---

## Quick Start

```swift
import AIProviderKit
import ClaudeProvider

let client = AIClient(
    provider: ClaudeProvider(
        authorization: APIKeyAuthorization(apiKey: "sk-ant-..."),
        logger: AILogger(subsystem: "com.myapp", category: "ai")
    )
)

let response = try await client.send(
    AIRequestBuilder()
        .model(.claudeSonnet4)
        .systemPrompt("You are a helpful assistant.")
        .addMessage(.user(text: "What is the capital of France?"))
        .build()
)
print(response.text)
```

---

## Examples

Full, copy-paste ready examples are in the [`Examples/`](Examples/) folder.

| File | What it shows |
|---|---|
| [`01_BasicChat.swift`](Examples/01_BasicChat.swift) | Single-turn and multi-turn conversation |
| [`02_StreamingChat.swift`](Examples/02_StreamingChat.swift) | SSE streaming integrated into a SwiftUI `@Observable` view model |
| [`03_ToolUse.swift`](Examples/03_ToolUse.swift) | Custom tools + predefined `CalendarTool` / `LocationTool`, auto-execution loop |
| [`04_RecipesAndSkills.swift`](Examples/04_RecipesAndSkills.swift) | Reusable prompt templates and composable Skills |
| [`05_LoggingSetup.swift`](Examples/05_LoggingSetup.swift) | `AILogStore` + `AILogView` debug sheet in a SwiftUI app |

### Streaming

```swift
for try await event in client.stream(request) {
    if case .textDelta(let chunk) = event {
        output += chunk
    }
}
```

### Tool use

```swift
// 1. Register tools
await client.toolRegistry.register(LocationTool.make())
await client.toolRegistry.registerAll(CalendarTool.self)

// 2. Send — tool calls are executed and followed up automatically
let response = try await client.send(
    AIRequestBuilder()
        .model(.claudeSonnet4)
        .tools(await client.toolRegistry.allTools)
        .addMessage(.user(text: "What events do I have near me this week?"))
        .build()
)
print(response.text)
```

---

## Architecture

```
AIProviderKit          Core protocols, models, builders, registries, client
ClaudeProvider         Anthropic Messages API implementation
AIProviderKitUI        SwiftUI log viewer (optional dependency)
```

See [`Documentation/Architecture.md`](Documentation/Architecture.md) for full class diagrams and sequence diagrams.

### Key types

| Type | Role |
|---|---|
| `AIClient` | Main entry point (actor). Orchestrates the provider, registries, and auto tool-execution loop. |
| `AIProvider` | Protocol every provider implements. |
| `StreamableProvider` | Extends `AIProvider` with SSE streaming. |
| `AIRequestBuilder` | Fluent, validated request construction. |
| `Tool` / `ToolGroup` | A callable function (or group of functions) the model can invoke. |
| `Recipe` | A `{{placeholder}}` prompt template. |
| `Skill` | A bundle of tools + recipe + post-processing logic. |
| `AILogger` | Wraps `os.Logger`; optionally forwards entries to `AILogStore`. |
| `AILogView` | SwiftUI view showing live log entries from `AILogStore`. |

---

## Tools

Register predefined tools or define your own:

```swift
// Predefined — bulk-register an entire ToolGroup
await client.toolRegistry.register(LocationTool.make())
await client.toolRegistry.registerAll(CalendarTool.self)
await client.toolRegistry.registerAll(RemindersTool.self)

// Custom
let myTool = Tool(
    name: "search_products",
    description: "Searches the product catalog.",
    inputSchema: .object(
        properties: ["query": .string(description: "Search query.")],
        required: ["query"]
    )
) { input async throws in
    let query = input["query"]?.stringValue ?? ""
    let results = try await ProductService.search(query)
    return .array(results.map { .string($0.name) })
}
await client.toolRegistry.register(myTool)
```

---

## Recipes

```swift
let recipe = Recipe(
    id: "summarize",
    name: "Summarizer",
    systemPrompt: "You are a concise summarizer.",
    userPromptTemplate: "Summarize in {{style}} style:\n\n{{text}}"
)
await client.recipeRegistry.register(recipe)

let response = try await client.send(
    recipe: recipe,
    values: ["style": "bullet points", "text": articleBody],
    model: .claudeSonnet4
)
```

---

## Logging

```swift
// Enable in-app log capture at startup
AILogStore.shared = AILogStore()

// Attach a logger to the provider
let logger = AILogger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "ai")
let provider = ClaudeProvider(authorization: auth, logger: logger)

// Show the log viewer in a debug sheet (import AIProviderKitUI)
.sheet(isPresented: $showLogs) {
    AILogView(store: AILogStore.shared ?? AILogStore())
}
```

All log entries are also written to the system log and visible in **Console.app**.

---

## Use Cases

Detailed use cases with code examples are in [`Documentation/UseCases.md`](Documentation/UseCases.md):

- UC-01 Simple text conversation
- UC-02 Multi-turn conversation
- UC-03 Streaming response
- UC-04 Automatic tool use
- UC-05 Recipe (prompt template)
- UC-06 Skill execution
- UC-07 In-app log viewer
- UC-08 Vision (image input)

---

## Extending

### Add a new provider

Implement `AIProvider` (and optionally `StreamableProvider`) — `AIClient` works with any conforming type. See [`Documentation/AddingAProvider.md`](Documentation/AddingAProvider.md) for a step-by-step walkthrough.

### CI / GitHub Actions

See [`Documentation/GitHubActions.md`](Documentation/GitHubActions.md) for the CI workflow, badge setup, and guidance on adding new workflows.

### Roadmap

See [`ROADMAP.md`](ROADMAP.md) for the full milestone plan. Highlights:

| Version | Focus |
|---|---|
| **0.1.0** | Claude provider, core architecture ✅ |
| **0.2.0** | OpenAI provider |
| **0.3.0** | Apple Foundation Models (on-device, iOS 26+) |
| **0.4.0** | Persistence — `ConversationStore` protocol + in-memory backend |
| **0.5.0** | Persistence — file system backend (`AIProviderKitPersistenceFS`) |
| **0.6.0** | Persistence — SwiftData backend (`AIProviderKitPersistenceDB`) |
| **1.0.0** | Full MVP — stable API, DocC, example app |

---

## Testing

### Unit tests

Run the full suite (no API key required — all providers are mocked):

```bash
swift test
```

### Integration tests

Integration tests exercise the real Claude API. Requires an `ANTHROPIC_API_KEY` environment variable.

```bash
# Via the SPM command plugin (recommended)
ANTHROPIC_API_KEY=sk-ant-... swift package integration-tests

# Or directly
ANTHROPIC_API_KEY=sk-ant-... swift run IntegrationTests
```

Covered scenarios:

| Test | What it verifies |
|---|---|
| Basic text completion | `AIClient.send()` returns a non-empty `endTurn` response |
| Streaming | `AIClient.stream()` emits `textDelta` events |
| Automatic tool execution | Tool registered, called by the model, auto-executed, final response returned |
| Recipe rendering | `{{placeholder}}` values substituted before send |
| Skill execution | Skill looked up, recipe applied as system prompt, output post-processed |

See [`Documentation/IntegrationTests.md`](Documentation/IntegrationTests.md) for full details and guidance on adding new test cases.

---

## Requirements

| | Minimum |
|---|---|
| iOS | 26.0 |
| macOS | 26.0 |
| Swift | 6.0 |
| Xcode | 26.x |

---

## License

MIT
