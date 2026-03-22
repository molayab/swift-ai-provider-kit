<p align="center">
  <img src="Documentation/Assets/banner.svg" alt="AIProviderKit" width="100%"/>
</p>

<p align="center">
  <a href="https://github.com/molayab/swift-ai-provider-kit/actions/workflows/ci.yml"><img src="https://github.com/molayab/swift-ai-provider-kit/actions/workflows/ci.yml/badge.svg" alt="CI"/></a>
  <img src="https://img.shields.io/badge/SwiftLint-enforced-orange?logo=swift&logoColor=white" alt="SwiftLint"/>
  <img src="https://img.shields.io/badge/Swift-6.2-orange?logo=swift&logoColor=white" alt="Swift 6"/>
  <img src="https://img.shields.io/badge/Platforms-iOS%2026%20%7C%20macOS%2026%20%7C%20visionOS%202-blue" alt="Platforms"/>
</p>

A modular Swift package for integrating AI providers in a provider-agnostic way. Swap between Claude, on-device Apple Intelligence, or future providers without changing application code — with built-in streaming, automatic tool execution, reusable prompt templates, and composable skills.

Built with Swift 6, full `Sendable` compliance, and SOLID principles throughout.

---

## Table of Contents

- [Providers](#providers)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Examples](#examples)
- [Runner CLI](#runner-cli)
- [Architecture](#architecture)
- [Roadmap](#roadmap)
- [Requirements](#requirements)
- [Contributing](#contributing)
- [License](#license)

---

## Providers

| Provider | Module | Status | Notes |
|---|---|---|---|
| **Claude** (Anthropic) | `ClaudeProvider` | ✅ Shipped | Full streaming, tools, vision |
| **Apple Intelligence** | `AppleIntelligenceProvider` | ✅ Shipped | On-device, iOS 26+ / macOS 26+, requires Apple Intelligence enabled |
| **OpenAI** | `OpenAIProvider` | ✅ Shipped | Chat Completions API — streaming, tools, vision, dynamic model listing |
| **Llama / local** | `LlamaProvider` | 💡 Post-1.0.0 | Wraps a locally-running `llama-server`; targets macOS, Linux, and Windows via OpenAI-compatible REST |

---

## Features

| Feature | Description |
|---|---|
| **Provider abstraction** | Swap providers without changing application code |
| **Automatic tool execution** | `AIClient` detects `toolUse` stop reasons and loops automatically until `endTurn` |
| **Streaming** | Server-sent event streaming via `AsyncThrowingStream` |
| **On-device inference** | Private, offline inference via Apple Intelligence (`FoundationModels`) |
| **Tools** | Atomic callables — a name, input schema, and async handler. No awareness of skills or agents. |
| **Recipes** | Reusable `{{placeholder}}` prompt templates decoupled from code. |
| **Skills** | Own a set of `Tool`s and an optional `Recipe`. Teach the model *how* to use those tools for a specific task; post-process the response into `SkillResult`. |
| **Registries** | Thread-safe `actor`-based stores for tools, skills, and recipes |
| **Structured logging** | `os.Logger`-backed `AILogger` with optional in-app capture via `AILogStore` |
| **Predefined tools** | `AIProviderTools` module — time, shell, AppleScript, file I/O, clipboard (macOS), calendar, reminders, and location, all via a unified `ToolGroup` interface |

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/molayab/swift-ai-provider-kit.git", from: "0.1.0")
]
```

Add the products you need:

```swift
.product(name: "AIProviderKit", package: "AIProviderKit"),            // Core (always required)
.product(name: "ClaudeProvider", package: "AIProviderKit"),            // Claude — Anthropic API
.product(name: "OpenAIProvider", package: "AIProviderKit"),            // OpenAI Chat Completions API
.product(name: "AppleIntelligenceProvider", package: "AIProviderKit"), // On-device Apple Intelligence
.product(name: "AIProviderTools", package: "AIProviderKit"),           // Ready-to-use tools (optional)
.product(name: "AIProviderKitNetworking", package: "AIProviderKit"),   // Shared HTTP + SSE client (for custom providers)
```

---

## Quick Start

### Claude (Anthropic)

```swift
import AIProviderKit
import ClaudeProvider

let client = AIClient(
    provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: "<YOUR_ANTHROPIC_API_KEY>"))
)

let response = try await client.send(
    AIRequestBuilder()
        .model(.claudeSonnet46)
        .systemPrompt("You are a helpful assistant.")
        .addMessage(.user(text: "What is the capital of France?"))
        .build()
)
print(response.text)
```

### OpenAI

```swift
import AIProviderKit
import OpenAIProvider

let provider = OpenAIProvider(authorization: BearerAuthorization(apiKey: "<OPENAI_API_KEY>"))
let client = AIClient(provider: provider)

let response = try await client.send(
    AIRequestBuilder()
        .model(.gpt4o)
        .systemPrompt("You are a helpful assistant.")
        .addMessage(.user(text: "What is the capital of France?"))
        .build()
)
print(response.text)

// Discover available models at runtime
let models = try await provider.listModels()
```

### Apple Intelligence (on-device)

```swift
import AIProviderKit
import AppleIntelligenceProvider

guard AppleIntelligenceAvailability.isAvailable else {
    // Device doesn't support Apple Intelligence — fall back to a remote provider
    return
}

let client = AIClient(provider: AppleIntelligenceProvider())

let response = try await client.send(
    AIRequestBuilder()
        .model(.appleIntelligenceDefault)
        .addMessage(.user(text: "Summarise this in one sentence."))
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
| [`02_StreamingChat.swift`](Examples/02_StreamingChat.swift) | SSE streaming in a SwiftUI `@Observable` view model |
| [`03_ToolUse.swift`](Examples/03_ToolUse.swift) | Custom tools + predefined `CalendarTool` / `LocationTool` |
| [`04_RecipesAndSkills.swift`](Examples/04_RecipesAndSkills.swift) | Reusable prompt templates and composable Skills |
| [`05_LoggingSetup.swift`](Examples/05_LoggingSetup.swift) | `AILogStore` log capture in a SwiftUI app |

### Streaming

```swift
for try await event in client.stream(request) {
    if case .textDelta(let chunk) = event {
        output += chunk
    }
}
```

### Tool use

Every tool in `AIProviderTools` conforms to `ToolGroup`, so registration is always the same call — whether the group has one tool or many:

```swift
import AIProviderTools

// All tools use the same ToolGroup interface
await client.toolRegistry.registerAll(CurrentTimeTool.self)
await client.toolRegistry.registerAll(CalendarTool.self)
await client.toolRegistry.registerAll(RemindersTool.self)
await client.toolRegistry.registerAll(LocationTool.self)
#if os(macOS)
await client.toolRegistry.registerAll(ShellCommandTool.self)   // run shell commands
await client.toolRegistry.registerAll(AppleScriptTool.self)    // automate macOS apps
await client.toolRegistry.registerAll(FileSystemTool.self)     // read / write files
await client.toolRegistry.registerAll(ClipboardTool.self)      // get / set clipboard
#endif

// Tool calls are executed and followed up automatically
let response = try await client.send(
    AIRequestBuilder()
        .model(.claudeSonnet46)
        .tools(await client.toolRegistry.allTools)
        .addMessage(.user(text: "What events do I have near me this week?"))
        .build()
)
```

For single-tool groups, the `tool` shorthand gives direct access when you only need the `Tool` value:

```swift
let timeTool = try CurrentTimeTool.tool()
await client.toolRegistry.register(timeTool)
```

### Custom tools

<details>
<summary>Define and register a custom tool</summary>

```swift
let searchTool = Tool(
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
await client.toolRegistry.register(searchTool)
```

</details>

### Recipes

```swift
let recipe = Recipe(
    id: "summarize",
    name: "Summarizer",
    systemPrompt: "You are a concise summarizer.",
    userPromptTemplate: "Summarize in {{style}} style:\n\n{{text}}"
)
let response = try await client.send(
    recipe: recipe,
    values: ["style": "bullet points", "text": articleBody],
    model: .claudeSonnet46
)
```

### Persistent conversations

`AIClient` ships with built-in conversation persistence. The default backend is in-memory; future milestones will add file-system and SwiftData backends.

```swift
// Create and persist a conversation
let conv = try await client.createConversation(model: .claudeSonnet46, title: "My Chat")

// Send messages — user and assistant turns are saved automatically
let reply = try await client.send(conversation: conv, message: "Hello!")

// Stream with auto-persistence (turns saved when stream completes)
for try await event in try await client.stream(conversation: conv, message: "Tell me more") {
    if case .textDelta(let text) = event { print(text, terminator: "") }
}

// Manage conversations
let all = try await client.store.listConversations()
try await client.delete(conversation: conv)
```

Pass a `tokenBudget` to automatically prune the oldest turns before sending:

```swift
let reply = try await client.send(
    conversation: conv,
    message: "Summarize so far",
    tokenBudget: 8_000
)
```

To use a specific store backend, pass it at init time:

```swift
let client = AIClient(
    provider: ClaudeProvider(authorization: auth),
    store: .ephemeralMemory   // default; .fileSystem and .database coming in 0.4.1 / 0.4.2
)
```

---

### Logging

```swift
// Capture logs in-app at startup
AILogStore.shared = AILogStore()

let provider = ClaudeProvider(
    authorization: auth,
    logger: AILogger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "ai")
)
```

All entries are also written to the system log and visible in **Console.app**.

---

## Runner CLI

The package ships a `Runner` executable that acts as a live playground for any provider. No Xcode project needed — just `swift run`.

```bash
# On-device Apple Intelligence (macOS 26 / iOS 26, no key required)
swift run Runner chat apple-intelligence

# Interactive streaming chat with Claude
ANTHROPIC_API_KEY=<YOUR_ANTHROPIC_API_KEY> swift run Runner chat claude

# Interactive streaming chat with OpenAI
OPENAI_API_KEY=<YOUR_OPENAI_API_KEY> swift run Runner chat openai
```

### Chat commands

| Command | Description |
|---|---|
| `/model <id>` | Switch to a different model mid-session |
| `/skill <skill-id> <text>` | Run a registered skill directly |
| `/benchmark [--runs <n>]` | Measure latency and throughput (default: 10 runs) |
| `/history` | Print the full conversation history |
| `/clear` | Reset conversation history |
| `/help` | Show all commands |
| `/quit` | Exit |

### macOS system tools (auto-registered)

On macOS, the Runner registers a full set of system interaction tools the model can call freely during chat:

| Tool | What it does |
|---|---|
| `get_current_time` | Returns the current date and time |
| `run_shell_command` | Runs any `/bin/zsh` command and returns stdout / stderr |
| `run_applescript` | Executes AppleScript to automate macOS apps and the UI |
| `read_file` / `write_file` | Reads or writes a UTF-8 file by path |
| `list_directory` | Returns names and types of entries in a directory |
| `get_clipboard` / `set_clipboard` | Reads or writes the system clipboard |

### Built-in skills (auto-registered)

| Skill | Invoke with |
|---|---|
| `title-generator` | `/skill title-generator <your text>` |
| `shell-explainer` *(macOS)* | `/skill shell-explainer <command or pipeline>` |

---

## Architecture

```
AIProviderKit              Core protocols, models, builders, registries, client
ClaudeProvider             Anthropic Messages API implementation
OpenAIProvider             OpenAI Chat Completions API implementation
AppleIntelligenceProvider  On-device inference via Apple Intelligence (iOS 26+ / macOS 26+)
AIProviderTools            Ready-to-use ToolGroup implementations (time, shell, AppleScript, file I/O, clipboard, calendar, reminders, location)
```

See [`Documentation/Architecture.md`](Documentation/Architecture.md) for class diagrams, sequence diagrams, and the concurrency model.

### Key types

| Type | Role |
|---|---|
| `AIClient` | **The agent.** Actor that owns the three registries, drives the automatic tool-execution loop, and routes requests to the active `AIProvider`. |
| `AIProvider` | Protocol every provider implements. |
| `StreamableProvider` | Extends `AIProvider` with SSE streaming. |
| `ModelDiscoveryProvider` | Extends `AIProvider` with runtime model listing (`listModels()`). |
| `AIModelInfo` | Model metadata returned by `listModels()` — id, display name, creation date. |
| `AIRequestBuilder` | Fluent, validated request construction. |
| `Tool` | Atomic callable — a name, `JSONSchema` input schema, and async handler. Owns nothing; has no awareness of skills or the agent. |
| `ToolGroup` | Namespace that vends one or more related `Tool`s for bulk registration. |
| `Recipe` | Reusable `{{placeholder}}` prompt template. Decouples prompt engineering from code. |
| `Skill` | Owns a set of `Tool`s and an optional `Recipe`. Teaches the model how to use those tools for a specific task and post-processes the response into `SkillResult`. |
| `ConversationStore` | Protocol for async CRUD on conversations and turns. |
| `SupportedConversationStore` | Enum selecting the active backend (`.ephemeralMemory`, `.fileSystem`, `.database`). |
| `AILogger` | Wraps `os.Logger`; optionally forwards entries to `AILogStore`. |

---

## Roadmap

See [`ROADMAP.md`](ROADMAP.md) for the full milestone plan.

| Version | Focus | Status |
|---|---|---|
| **0.1.0** | Core architecture + Claude provider | ✅ Shipped |
| **0.2.0** | Apple Intelligence provider (on-device) | ✅ Shipped |
| **0.3.0** | OpenAI provider + `ModelDiscoveryProvider` | ✅ Shipped |
| **0.3.1** | Dynamic model discovery for `ClaudeProvider` | ✅ Shipped |
| **0.3.2** | Shared HTTP networking layer (`AIProviderKitNetworking`) | ✅ Shipped |
| **0.4.0** | Persistence — core protocol + in-memory backend | ✅ Shipped |
| **0.4.1** | Persistence — file system backend | 🔜 Planned |
| **0.4.2** | Persistence — SwiftData backend | 🔜 Planned |
| **0.5.0** | RAG — embedding protocol + in-memory vector store | 🔜 Planned |
| **1.0.0** | Stable API, DocC, example app | 🔜 Planned |

---

## Testing

```bash
# Unit tests — no API key required
swift test

# Integration tests — requires ANTHROPIC_API_KEY
ANTHROPIC_API_KEY=<YOUR_ANTHROPIC_API_KEY> swift package integration-tests
```

See [`Documentation/IntegrationTests.md`](Documentation/IntegrationTests.md) for full details.

---

## Requirements

| Platform | Minimum | Notes |
|---|---|---|
| iOS | 26.0 | Full support |
| macOS | 26.0 | Full support |
| visionOS | 2.0 | Core providers only — `CalendarTool` and `RemindersTool` unavailable (no EventKit) |
| **Swift** | **6.0** | |
| **Xcode** | **26.0+** | |

> **External dependencies:** none. All products use only the Swift standard library and `Foundation`. `AppleIntelligenceProvider` additionally requires the `FoundationModels` framework (iOS 26+ / macOS 26+).

---

## Contributing

Contributions are welcome — bug reports, feature requests, and pull requests.

- To add a new AI provider, see [`Documentation/AddingAProvider.md`](Documentation/AddingAProvider.md).
- For CI setup, see [`Documentation/GitHubActions.md`](Documentation/GitHubActions.md).

Please open an issue before starting significant work so we can align on direction.

---

## License

AIProviderKit is released under the **MIT License**.

Copyright © 2026 Mateo Olaya Bernal. See [`LICENSE`](LICENSE) for the full text.
