import AIProviderKit
import AIProviderTools
import Foundation

/// Runs an interactive, multi-turn streaming chat session in the terminal.
///
/// Every conversation is persisted in the `AIClient`'s store so it can be
/// listed, resumed, or archived at any time. Special `/` commands let the user
/// manage conversations, switch models, or invoke registered skills.
///
/// Example tools and skills are registered automatically:
/// - `get_current_time` tool — the model calls this when asked about time/date.
/// - `title-generator` skill — invoke with `/skill title-generator <text>`.
actor ChatSession {
    private let client: AIClient
    private let providerName: String
    private var currentModel: AIModel
    private var conversation: Conversation?

    /// System prompt sent with every request.
    private let systemPrompt = """
        You are a capable assistant. Use tools autonomously. Chain tool calls; clarify only when ambiguous.
        """

    init(client: AIClient, providerName: String, defaultModel: AIModel) {
        self.client = client
        self.providerName = providerName
        self.currentModel = defaultModel
    }

    // MARK: - Run

    func run() async {
        await registerExamples()
        await startNewConversation(title: sessionTitle())
        printWelcome()

        while true {
            printPrompt()

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
        await client.toolRegistry.registerAll(DebugTool.self)
        #if os(macOS)
        await client.toolRegistry.register(ShellCommandTool.shellCommand)
        await client.toolRegistry.register(AppleScriptTool.runScript)
        await client.toolRegistry.registerAll(FileSystemTool.self)
        await client.toolRegistry.registerAll(ClipboardTool.self)
        await client.skillRegistry.register(ShellExplainerSkill())
        #endif
        await client.skillRegistry.register(TitleGeneratorSkill())
    }

    // MARK: - Conversation management

    private func startNewConversation(title: String) async {
        do {
            conversation = try await client.createConversation(model: currentModel, title: title)
            print("  conversation: \"\(title)\"")
        } catch {
            print("error: could not create conversation: \(error)")
        }
    }

    private func listConversations() async {
        do {
            let all = try await client.conversations()
            if all.isEmpty {
                print("No saved conversations.")
                return
            }
            print("\nSaved conversations:")
            for (i, conv) in all.enumerated() {
                let active   = conv.id == conversation?.id ? "▶" : " "
                let archived = conv.isArchived ? " [archived]" : ""
                let turns    = conv.turns.count / 2
                print("  \(active) \(i + 1).  \(conv.title)")
                print("          model: \(conv.model.identifier)  turns: \(turns)\(archived)")
            }
        } catch {
            print("error listing conversations: \(error)")
        }
    }

    private func resumeConversation(indexArg: String) async {
        guard let index = Int(indexArg), index > 0 else {
            print("Usage: /resume <n>  — use /conversations to see the list")
            return
        }
        do {
            let all = try await client.conversations()
            guard all.indices.contains(index - 1) else {
                print("No conversation at position \(index).")
                return
            }
            let latest = all[index - 1]
            conversation = latest
            currentModel = latest.model
            let turns = latest.turns.count / 2
            print("Resumed: \"\(latest.title)\" — \(turns) prior turn\(turns == 1 ? "" : "s") · model: \(latest.model.identifier)")
        } catch {
            print("error: \(error)")
        }
    }

    private func archiveCurrentConversation() async {
        guard let conv = conversation else {
            print("No active conversation.")
            return
        }
        do {
            try await client.archive(conversation: conv)
            print("Archived: \"\(conv.title)\"")
            await startNewConversation(title: sessionTitle())
        } catch {
            print("error: \(error)")
        }
    }

    // MARK: - Commands

    /// Returns `true` when the session should exit.
    private func handleCommand(_ input: String) async -> Bool {
        let parts = input.split(separator: " ", maxSplits: 1).map(String.init)
        switch parts[0].lowercased() {
        case "/quit", "/exit":
            return true
        case "/new":
            let title = parts.count > 1 ? parts[1] : sessionTitle()
            await startNewConversation(title: title)
        case "/clear":
            await startNewConversation(title: sessionTitle())
        case "/conversations":
            await listConversations()
        case "/resume":
            await resumeConversation(indexArg: parts.count > 1 ? parts[1] : "")
        case "/archive":
            await archiveCurrentConversation()
        case "/model":
            if parts.count > 1 {
                currentModel = AIModel(parts[1])
                print("Model set to \(parts[1]). Starting new conversation…")
                await startNewConversation(title: sessionTitle())
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
        do {
            let result = try await client.execute(skillId: parts[0], input: parts[1], model: currentModel)
            print("\nSkill [\(parts[0])]: \(result.output)")
        } catch {
            print("\nerror running skill '\(parts[0])': \(error)")
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
        guard let conv = conversation else {
            print("No active conversation. Type /new to start one.")
            return
        }

        do {
            let events = try await client.stream(conversation: conv, message: text, systemPrompt: systemPrompt)

            print("\n\(providerName): ", terminator: "")
            fflush(stdout)

            for try await event in events {
                if case .textDelta(let delta) = event {
                    print(delta, terminator: "")
                    fflush(stdout)
                }
            }
            print()

            // Refresh the local reference so the next send sees the persisted turns.
            conversation = try await client.conversation(byId: conv.id) ?? conv

        } catch let aiError as AIError {
            switch aiError {
            case .contextLengthExceeded:
                print("\n(context window full — type /new for a fresh conversation, or /model <id> for a larger context)")
            case .providerUnsupported(let cap) where cap == .streaming:
                // Fall back to non-streaming send
                await sendMessageNonStreaming(text)
            default:
                print("\nerror: \(aiError)")
            }
        } catch {
            print("\nerror: \(error)")
        }
    }

    /// Non-streaming fallback used when the active provider does not support SSE.
    private func sendMessageNonStreaming(_ text: String) async {
        guard let conv = conversation else { return }
        do {
            print("\n\(providerName): ", terminator: "")
            fflush(stdout)
            let response = try await client.send(conversation: conv, message: text, systemPrompt: systemPrompt)
            print(response.text)
            conversation = try await client.conversation(byId: conv.id) ?? conv
        } catch {
            print("\nerror: \(error)")
        }
    }

    // MARK: - Display helpers

    private func printHistory() {
        guard let conv = conversation else {
            print("No active conversation.")
            return
        }
        if conv.turns.isEmpty {
            print("No turns yet in \"\(conv.title)\".")
            return
        }
        print("\nConversation: \"\(conv.title)\"")
        for turn in conv.turns {
            print("\(turn.message.role.rawValue.capitalized): \(turn.message.text)")
        }
    }

    private func printPrompt() {
        let title = conversation.map { " [\($0.title)]" } ?? ""
        print("\nYou\(title): ", terminator: "")
        fflush(stdout)
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
          /new [title]                 Start a new conversation (optional title)
          /conversations               List all saved conversations
          /resume <n>                  Resume conversation by number from /conversations
          /archive                     Archive the current conversation and start fresh
          /clear                       Start a new conversation (alias for /new)
          /history                     Print the current conversation's turns
          /model                       Show current model
          /model <id>                  Switch model and start a new conversation
          /skill <skill-id> <text>     Run a skill on the given text
          /benchmark [--runs <n>]      Run latency/throughput benchmark (default: 10 runs)
          /help                        Show this help
          /quit, /exit                 Exit

        Built-in tools (registered automatically):
          get_current_time             Ask "what time is it?" to see it in action
          echo                         Ask the model to echo a message (confirms tool calling works)
          runtime_info                 Ask the model for runtime/environment details
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

    private func sessionTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "Session \(formatter.string(from: Date()))"
    }
}
