import AIProviderKit
import AIProviderTools
import Foundation

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

    /// System prompt sent with every request.
    /// Instructs the model to use tools autonomously rather than asking the user
    /// for information a tool can retrieve. Kept short for Apple Intelligence's
    /// 4 096-token context budget.
    private let systemPrompt = """
        You are a capable assistant. Use tools autonomously — never ask for \
        information a tool can retrieve. Chain tool calls; clarify only when ambiguous.
        """

    /// Tools included in every request so the model can invoke them freely.
    private let tools: [Tool] = {
        var all: [Tool] = [CurrentTimeTool.currentTime]
        #if os(macOS)
        all += [ShellCommandTool.shellCommand, AppleScriptTool.runScript] + FileSystemTool.all + ClipboardTool.all
        #endif
        return all
    }()

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
        await client.toolRegistry.register(AppleScriptTool.runScript)
        await client.toolRegistry.registerAll(FileSystemTool.self)
        await client.toolRegistry.registerAll(ClipboardTool.self)
        await client.skillRegistry.register(ShellExplainerSkill())
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
            printHistory()
        case "/skill":
            await handleSkill(parts.count > 1 ? parts[1] : "")
        case "/benchmark":
            await handleBenchmark(parts.count > 1 ? parts[1] : "")
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

    // MARK: - Benchmark command

    private func handleBenchmark(_ args: String) async {
        let parts = args.split(separator: " ").map(String.init)
        let runs = parts.firstIndex(of: "--runs")
            .flatMap { parts.indices.contains($0 + 1) ? Int(parts[$0 + 1]) : nil }
            .flatMap { $0 > 0 ? $0 : nil }
            ?? 10
        await BenchmarkSuite(client: client, model: currentModel, providerName: providerName, runs: runs).run()
    }

    // MARK: - Messaging

    private func sendMessage(_ text: String) async {
        history.append(.user(text: text))

        // `dropCount` tracks how many messages to drop from the front of history
        // when retrying after a context-length overflow. Each retry sheds the
        // oldest exchange (one user + one assistant message) until the request fits
        // or only the current turn remains (at which point we give up).
        var dropCount = 0
        while true {
            let requestHistory = dropCount > 0 ? Array(history.dropFirst(dropCount)) : history

            do {
                let request = try AIRequestBuilder()
                    .model(currentModel)
                    .systemPrompt(systemPrompt)
                    .messages(requestHistory)
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
                return

            } catch let aiError as AIError {
                switch aiError {
                case .contextLengthExceeded:
                    let dropMore = dropCount + 2
                    if dropMore < history.count {
                        if dropCount == 0 {
                            print("(context window full — trimming oldest history to fit…)")
                        }
                        dropCount = dropMore
                        // Loop and retry with fewer messages.
                    } else {
                        print("\nerror: the content is too large to fit in this model's context window.")
                        print("       Try /model claude-sonnet-4-6 for a much larger context, or read")
                        print("       the file in chunks with the maxChars parameter.")
                        history.removeLast()
                        return
                    }
                default:
                    print("\nerror: \(aiError)")
                    history.removeLast()
                    return
                }
            } catch {
                print("\nerror: \(error)")
                history.removeLast()
                return
            }
        }
    }

    // MARK: - Help

    private func printHistory() {
        if history.isEmpty {
            print("No conversation history.")
        } else {
            for message in history {
                print("\(message.role.rawValue.capitalized): \(message.text)")
            }
        }
    }

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
          /benchmark [--runs <n>]      Run latency/throughput benchmark (default: 10 runs)
          /clear                       Clear conversation history
          /history                     Print conversation history
          /help                        Show this help
          /quit, /exit                 Exit

        Built-in tools (registered automatically):
          get_current_time             Ask "what time is it?" to see it in action
        """
        #if os(macOS)
        help += "\n          run_shell_command            Ask the model to run any shell command"
        help += "\n          run_applescript              Ask the model to automate macOS apps via AppleScript"
        help += "\n          read_file / write_file       Ask the model to read or write any file"
        help += "\n          list_directory               Ask the model to list a directory"
        help += "\n          get_clipboard / set_clipboard  Read or write the system clipboard"
        #endif
        help += "\n\n        Built-in skills:\n          title-generator              /skill title-generator <your text here>"
        #if os(macOS)
        help += "\n          shell-explainer              /skill shell-explainer <command or pipeline>"
        #endif
        print(help)
    }
}
