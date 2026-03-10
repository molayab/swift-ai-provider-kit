# Use Cases

## UC-01 · Simple Text Conversation

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

**Actor:** iOS app
**Goal:** Let the model call device tools automatically (e.g. weather, location).

```swift
await client.toolRegistry.register(LocationTool.make())
await client.toolRegistry.register(CalendarTool.listEvents)

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
