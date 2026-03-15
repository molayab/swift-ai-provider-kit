import Foundation
import AIProviderKit
import AIProviderTools

/// Runs an interactive, multi-turn streaming chat session in the terminal.
///
/// Conversation history is kept in memory for the lifetime of the session so
/// each response has full context of prior turns. Special `/` commands let the
/// user switch models, clear history, or invoke registered skills.
///
/// Example tools and skills are registered automatically:
/// - `get_current_time` tool — the model calls this when asked about time/date.
/// - `title-generator` skill — invoke with `/skill title-generator <text>`.
actor ChatSession {
    private let client: AIClient
    private let providerName: String
    private var currentModel: AIModel
    private var history: [Message] = []

    /// Tools included in every request so the model can invoke them freely.
    private var tools: [Tool] {
        var all: [Tool] = [CurrentTimeTool.currentTime]
        #if os(macOS)
        all.append(ShellCommandTool.shellCommand)
        #endif
        return all
    }

    init(client: AIClient, providerName: String, defaultModel: AIModel) {
        self.client = client
        self.providerName = providerName
        self.currentModel = defaultModel
    }

    // MARK: - Run

    func run() async {
        await registerExamples()
        printWelcome()

        while true {
            print("\nYou: ", terminator: "")
            fflush(stdout)

            guard let line = readLine(strippingNewline: true) else { break }
            let input = line.trimmingCharacters(in: .whitespaces)
            guard !input.isEmpty else { continue }

            if input.hasPrefix("/") {
                let shouldQuit = await handleCommand(input)
                if shouldQuit { break }
                continue
            }

            await sendMessage(input)
        }

        print("\nGoodbye!")
    }

    // MARK: - Setup

    private func registerExamples() async {
        await client.toolRegistry.register(CurrentTimeTool.currentTime)
        #if os(macOS)
        await client.toolRegistry.register(ShellCommandTool.shellCommand)
        #endif
        await client.skillRegistry.register(TitleGeneratorSkill())
    }

    // MARK: - Commands

    /// Returns `true` when the session should exit.
    private func handleCommand(_ input: String) async -> Bool {
        let parts = input.split(separator: " ", maxSplits: 1).map(String.init)
        switch parts[0].lowercased() {
        case "/quit", "/exit":
            return true
        case "/clear":
            history = []
            print("Conversation cleared.")
        case "/model":
            if parts.count > 1 {
                currentModel = AIModel(parts[1])
                print("Model set to \(parts[1]).")
            } else {
                print("Current model: \(currentModel.identifier)")
                print("Usage: /model <model-id>")
            }
        case "/history":
            if history.isEmpty {
                print("No conversation history.")
            } else {
                for message in history {
                    let role = message.role.rawValue.capitalized
                    print("\(role): \(message.text)")
                }
            }
        case "/skill":
            await handleSkill(parts.count > 1 ? parts[1] : "")
        case "/help":
            printHelp()
        default:
            print("Unknown command '\(parts[0])'. Type /help for available commands.")
        }
        return false
    }

    // MARK: - Skill command

    private func handleSkill(_ args: String) async {
        let parts = args.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            print("Usage: /skill <skill-id> <input text>")
            print("Available skills: title-generator")
            return
        }
        let skillId = parts[0]
        let text    = parts[1]

        do {
            let result = try await client.execute(skillId: skillId, input: text, model: currentModel)
            print("\nSkill [\(skillId)]: \(result.output)")
        } catch {
            print("\nerror running skill '\(skillId)': \(error)")
        }
    }

    // MARK: - Messaging

    private func sendMessage(_ text: String) async {
        history.append(.user(text: text))

        do {
            let request = try AIRequestBuilder()
                .model(currentModel)
                .messages(history)
                .tools(tools)
                .maxTokens(2_048)
                .build()

            print("\n\(providerName): ", terminator: "")
            fflush(stdout)

            var fullText = ""
            for try await event in await client.stream(request) {
                if case .textDelta(let delta) = event {
                    print(delta, terminator: "")
                    fflush(stdout)
                    fullText += delta
                }
            }
            print()

            history.append(.assistant(text: fullText))
        } catch {
            print("\nerror: \(error)")
            history.removeLast()
        }
    }

    // MARK: - Help

    private func printWelcome() {
        print("─────────────────────────────────────────────")
        print("  runner chat · \(providerName) · \(currentModel.identifier)")
        print("  Type /help for commands, /quit to exit.")
        print("─────────────────────────────────────────────")
    }

    private func printHelp() {
        var help = """

        Commands:
          /model                       Show current model
          /model <id>                  Switch model (e.g. /model claude-opus-4-6)
          /skill <skill-id> <text>     Run a skill on the given text
          /clear                       Clear conversation history
          /history                     Print conversation history
          /help                        Show this help
          /quit, /exit                 Exit

        Built-in tools (registered automatically):
          get_current_time             Ask "what time is it?" to see it in action
        """
        #if os(macOS)
        help += "\n          run_shell_command            Ask the model to run any shell command"
        #endif
        help += "\n\n        Built-in skills:\n          title-generator              /skill title-generator <your text here>"
        print(help)
    }
}
