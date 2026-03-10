/// Example: Basic single-turn and multi-turn chat
///
/// Demonstrates:
///   - Setting up `ClaudeProvider` and `AIClient`
///   - Sending a single message
///   - Maintaining conversation history for multi-turn chat

import AIProviderKit
import ClaudeProvider

// MARK: - Setup

let authorization = APIKeyAuthorization(apiKey: "sk-ant-YOUR_KEY_HERE")
let provider = ClaudeProvider(
    authorization: authorization,
    logger: AILogger(subsystem: "com.example.app", category: "chat")
)
let client = AIClient(provider: provider)

// MARK: - Single turn

func singleTurn() async throws {
    let response = try await client.send(
        AIRequestBuilder()
            .model(.claudeSonnet4)
            .systemPrompt("You are a helpful assistant.")
            .addMessage(.user(text: "What is the capital of France?"))
            .maxTokens(256)
            .build()
    )

    print(response.text)
    print("Tokens used: \(response.usage.totalTokens)")
}

// MARK: - Multi-turn (conversation history)

func multiTurnChat() async throws {
    var history: [Message] = [
        .system("You are a helpful assistant. Keep answers brief.")
    ]

    func send(_ userInput: String) async throws -> String {
        history.append(.user(text: userInput))

        let response = try await client.send(
            AIRequestBuilder()
                .model(.claudeSonnet4)
                .messages(history)
                .build()
        )

        let assistantText = response.text
        history.append(.assistant(text: assistantText))
        return assistantText
    }

    let first  = try await send("Hi! My name is Alice.")
    let second = try await send("What is my name?")

    print(first)   // "Hi Alice! …"
    print(second)  // "Your name is Alice."
}
