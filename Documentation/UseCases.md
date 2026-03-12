# Use Cases

## Contents

| # | Use Case | Status |
|---|---|---|
| [UC-01](#uc-01--simple-text-conversation) | Simple Text Conversation | ✅ 0.1.0 |
| [UC-02](#uc-02--multi-turn-conversation) | Multi-Turn Conversation | ✅ 0.1.0 |
| [UC-03](#uc-03--streaming-response) | Streaming Response | ✅ 0.1.0 |
| [UC-04](#uc-04--tool-use-automatic) | Tool Use (Automatic) | ✅ 0.1.0 |
| [UC-05](#uc-05--recipe-prompt-template) | Recipe (Prompt Template) | ✅ 0.1.0 |
| [UC-06](#uc-06--skill-execution) | Skill Execution | ✅ 0.1.0 |
| [UC-07](#uc-07--in-app-log-viewer) | In-App Log Viewer | ✅ 0.1.0 |
| [UC-08](#uc-08--vision-image-input) | Vision (Image Input) | ✅ 0.1.0 |
| [UC-09](#uc-09--custom-tool-definition) | Custom Tool Definition | ✅ 0.1.0 |
| [UC-10](#uc-10--provider-swap) | Provider Swap | ⏳ 0.1.0+ |
| [UC-11](#uc-11--ephemeral-conversation-store-planned--040) | Ephemeral Conversation Store | 🔜 0.4.0 |
| [UC-12](#uc-12--file-system-persistence-planned--050) | File System Persistence | 🔜 0.5.0 |
| [UC-13](#uc-13--swiftdata-persistence-planned--060) | SwiftData Persistence | 🔜 0.6.0 |
| [UC-14](#uc-14--folder-as-context-planned--070--077) | Folder-as-Context | 🔜 0.7.0–0.7.7 |

---

## UC-01 · Simple Text Conversation

> **Status:** Available — 0.1.0

**Actor:** iOS app
**Goal:** Exchange a message with an AI model and display the response.

```swift
let client = AIClient(
    provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: key))
)

let response = try await client.send(
    AIRequestBuilder()
        .model(.claudeSonnet4)
        .addMessage(.user(text: "What is the capital of France?"))
        .build()
)
print(response.text)
```

---

## UC-02 · Multi-Turn Conversation

> **Status:** Available — 0.1.0

**Actor:** iOS app
**Goal:** Maintain conversation history across multiple turns.

```swift
var history: [Message] = [.system("You are a helpful assistant.")]

func chat(_ userInput: String) async throws -> String {
    history.append(.user(text: userInput))
    let response = try await client.send(
        AIRequestBuilder()
            .model(.claudeSonnet4)
            .messages(history)
            .build()
    )
    history.append(.assistant(text: response.text))
    return response.text
}
```

---

## UC-03 · Streaming Response

> **Status:** Available — 0.1.0

**Actor:** iOS app (SwiftUI)
**Goal:** Display text incrementally as it is generated.

```swift
@State private var output = ""

func startStream() async throws {
    let request = try AIRequestBuilder()
        .model(.claudeSonnet4)
        .addMessage(.user(text: "Write a short poem."))
        .build()

    for try await event in client.stream(request) {
        if case .textDelta(let chunk) = event {
            output += chunk
        }
    }
}
```

---

## UC-04 · Tool Use (Automatic)

> **Status:** Available — 0.1.0

**Actor:** iOS app
**Goal:** Let the model call device tools automatically (e.g. weather, location).

```swift
await client.toolRegistry.register(LocationTool.make())
await client.toolRegistry.registerAll(CalendarTool.self)

let response = try await client.send(
    AIRequestBuilder()
        .model(.claudeSonnet4)
        .tools(await client.toolRegistry.allTools)
        .addMessage(.user(text: "What events do I have near me this week?"))
        .build()
)
// AIClient executes tools automatically and returns the final answer.
print(response.text)
```

---

## UC-05 · Recipe (Prompt Template)

> **Status:** Available — 0.1.0

**Actor:** iOS app
**Goal:** Render a reusable prompt template and send it.

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

## UC-06 · Skill Execution

> **Status:** Available — 0.1.0

**Actor:** iOS app
**Goal:** Run a registered `Skill` that combines tools, a recipe, and post-processing.

```swift
let skill = SummarizationSkill()
await client.skillRegistry.register(skill)

let result = try await client.execute(
    skillId: "summarize",
    input: longText,
    model: .claudeSonnet4
)
print(result.output)
print("Tokens used: \(result.usage.totalTokens)")
```

---

## UC-07 · In-App Log Viewer

> **Status:** Available — 0.1.0

**Actor:** Developer / QA
**Goal:** Inspect AI request/response logs during debugging.

```swift
// AppDelegate or @main
AILogStore.shared = AILogStore()

// In any debug settings sheet:
.sheet(isPresented: $showLogs) {
    AILogView(store: AILogStore.shared ?? AILogStore())
}
```

---

## UC-08 · Vision (Image Input)

> **Status:** Available — 0.1.0

**Actor:** iOS app
**Goal:** Send an image alongside text for visual analysis.

```swift
let imageData: Data = ... // UIImage -> PNG/JPEG data
let response = try await client.send(
    AIRequestBuilder()
        .model(.claudeSonnet4)
        .addMessage(.user {
            ContentBlock.text("What is in this image?")
            ContentBlock.image(.init(source: .base64(mediaType: "image/jpeg", data: imageData)))
        })
        .build()
)
```

---

## UC-09 · Custom Tool Definition

> **Status:** Available — 0.1.0

**Actor:** iOS/macOS app
**Goal:** Define a custom tool that the model can invoke during a conversation.

```swift
// 1. Define the tool
let searchTool = Tool(
    name: "search_products",
    description: "Searches the product catalog by keyword.",
    inputSchema: .object(
        properties: [
            "query": .string(description: "The search keyword."),
            "limit": .integer(description: "Maximum number of results (default 5).")
        ],
        required: ["query"]
    )
) { input async throws in
    let query = input["query"]?.stringValue ?? ""
    let limit = input["limit"]?.intValue ?? 5
    let results = try await ProductService.search(query, limit: limit)
    return .array(results.map { .string($0.name) })
}

// 2. Register and send — the model calls the tool automatically
await client.toolRegistry.register(searchTool)

let response = try await client.send(
    AIRequestBuilder()
        .model(.claudeSonnet4)
        .tools(await client.toolRegistry.allTools)
        .addMessage(.user(text: "Find me some running shoes."))
        .build()
)
print(response.text)
```

---

## UC-10 · Provider Swap

> **Status:** Partially available — 0.1.0 (`ClaudeProvider` only). `OpenAIProvider` planned for 0.2.0; `FoundationModelProvider` planned for 0.3.0.

**Actor:** iOS/macOS app
**Goal:** Switch AI providers without changing any application logic.

```swift
// Shared request — identical for every provider
func makeRequest(userMessage: String) throws -> AIRequest {
    try AIRequestBuilder()
        .model(AppSettings.currentModel)
        .systemPrompt("You are a helpful assistant.")
        .addMessage(.user(text: userMessage))
        .build()
}

// Swap the provider in one place — all call sites are unaffected
func makeClient(for provider: AppSettings.Provider) -> AIClient {
    switch provider {
    case .claude:
        // Available — 0.1.0
        return AIClient(
            provider: ClaudeProvider(
                authorization: APIKeyAuthorization(apiKey: Secrets.anthropicKey)
            )
        )
    case .openAI:
        // Planned — 0.2.0
        return AIClient(
            provider: OpenAIProvider(
                authorization: APIKeyAuthorization(apiKey: Secrets.openAIKey)
            )
        )
    case .onDevice:
        // Planned — 0.3.0
        return AIClient(provider: FoundationModelProvider())
    }
}

// Usage — identical regardless of provider
let response = try await makeClient(for: AppSettings.current).send(makeRequest(userMessage: "Hello!"))
print(response.text)
```

---

## UC-11 · Ephemeral Conversation Store *(planned — 0.4.0)*

> **Status:** Not yet implemented. API shown below reflects the planned design.

**Actor:** iOS/macOS app
**Goal:** Persist conversation history in memory for the lifetime of the app session, with automatic turn saving and loading managed by `AIClient`.

```swift
// Zero-dependency default — conversations live in memory, lost on restart
let client = AIClient(
    provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: key)),
    store: .ephemeralMemory
)

// Start or continue a conversation by ID
let conversationId = UUID()

let response = try await client.send(
    conversationId: conversationId,
    message: "What did we discuss earlier?",
    model: .claudeSonnet4
)
// AIClient loads the existing turns, appends the new message,
// sends the full history, and saves the response — automatically.
print(response.text)

// List all stored conversations
let conversations = try await client.conversations()
```

---

## UC-12 · File System Persistence *(planned — 0.5.0)*

> **Status:** Not yet implemented. Requires `AIProviderKitPersistenceFS`.

**Actor:** iOS/macOS app
**Goal:** Persist conversations to disk so they survive app restarts. Works on every Apple platform and Linux with no extra frameworks.

```swift
import AIProviderKitPersistenceFS

let client = AIClient(
    provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: key)),
    store: .fileSystem(directory: .applicationSupport)
)

// Continue a previous conversation by ID — turns are loaded from disk
let response = try await client.send(
    conversationId: savedConversationId,
    message: "Continue from where we left off.",
    model: .claudeSonnet4
)

// Export a conversation as a portable JSON bundle
let bundle = try await client.export(conversationId: savedConversationId)
try bundle.write(to: exportURL)
```

---

## UC-13 · SwiftData Persistence *(planned — 0.6.0)*

> **Status:** Not yet implemented. Requires `AIProviderKitPersistenceDB` (iOS 17+ / macOS 14+).

**Actor:** iOS/macOS app
**Goal:** Store conversations in a SwiftData model container for full querying, indexing, and multi-process access.

```swift
import AIProviderKitPersistenceDB
import SwiftData

let client = AIClient(
    provider: ClaudeProvider(authorization: APIKeyAuthorization(apiKey: key)),
    store: .database(configuration: ModelConfiguration("Conversations"))
)

// Query conversations by model or date (predicate-based search)
let recent = try await client.conversations(
    where: \.model == .claudeSonnet4,
    sortedBy: \.updatedAt,
    order: .reverse,
    limit: 20
)

// SwiftUI list — backed by @Query, updates automatically
struct ConversationList: View {
    @Query(sort: \ConversationEntity.updatedAt, order: .reverse)
    var conversations: [ConversationEntity]

    var body: some View {
        List(conversations) { conversation in
            Text(conversation.title)
        }
    }
}
```

---

## UC-14 · Folder-as-Context *(planned — 0.7.0 – 0.7.7)*

> **Status:** Not yet implemented. Requires `AIProviderKitContext`. See [`Documentation/Issues/context-retrieval.md`](Issues/context-retrieval.md) for the full design.

**Actor:** iOS/macOS app
**Goal:** Augment model requests with relevant chunks retrieved from a local document folder, keeping answers grounded in app-specific content.

```swift
import AIProviderKitContext

// 1. Index a local folder (async, happens once)
let docsContext = try await FolderContext(
    url: Bundle.main.url(forResource: "Docs", withExtension: nil)!,
    embeddingProvider: VoyageEmbeddingProvider(apiKey: Secrets.voyageKey),
    options: FolderContextOptions(topK: 4)
)

// 2. At query time — retrieve and inject relevant context
let query = "How do I reset my password?"
let retrieved = try await docsContext.retrieve(for: query)

let response = try await client.send(
    AIRequestBuilder()
        .model(.claudeSonnet4)
        .context(retrieved)              // injects retrieved chunks as ContentBlocks
        .addMessage(.user(text: query))
        .build()
)
print(response.text)
```

### On-device path (no embedding API)

```swift
import AIProviderKitContext

// NLEmbeddingProvider uses Apple's NaturalLanguage framework — no API key required
let docsContext = try await FolderContext(
    url: localDocsURL,
    embeddingProvider: NLEmbeddingProvider(),
    options: FolderContextOptions(topK: 1)   // FoundationModelProvider has ~3K token budget
)
```

### OpenAI managed path (optional)

```swift
// Skip the client-side pipeline entirely — delegate retrieval to OpenAI
let response = try await client.send(
    AIRequestBuilder()
        .model(.gpt4o)
        .tools([.fileSearch(vectorStoreIds: ["vs_abc123"])])
        .addMessage(.user(text: "What does our refund policy say?"))
        .build()
)
```
