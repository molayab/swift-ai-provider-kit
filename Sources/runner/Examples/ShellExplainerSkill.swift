// ShellCommandTool — and therefore this skill — is macOS-only.
#if os(macOS)
import AIProviderKit
import AIProviderTools

/// Example skill: explains any zsh command or pipeline in plain language.
///
/// The model can call `ShellCommandTool` to inspect man pages and help text before
/// producing a breakdown of what the command does, its flags, data flow, and any hazards.
///
/// Invoke from the chat REPL with:
///   /skill shell-explainer <command>
///
/// Examples:
///   /skill shell-explainer find . -name "*.swift" | xargs grep -l "actor"
///   /skill shell-explainer awk '{print $2}' /etc/hosts
///   /skill shell-explainer tar -czf archive.tar.gz ./src
struct ShellExplainerSkill: Skill {
    let identifier = "shell-explainer"
    let description = "Explains any zsh command or pipeline — flags, data flow, side effects, and hazards."

    var tools: [Tool] { [ShellCommandTool.shellCommand] }

    var recipe: Recipe? {
        Recipe(
            id: "shell-explainer-recipe",
            name: "Shell Explainer",
            description: "Explains zsh commands and pipelines with full context.",
            systemPrompt: """
            You are ShellSage — an expert zsh and Unix shell developer. \
            Your job is to explain shell commands and pipelines clearly and precisely.

            When given a command:
            1. Use the available shell tool to gather context where useful — for example, \
               run `man -P cat <command>`, `<command> --help`, or `type -a <command>` \
               to verify flags and behaviour before explaining.
            2. Start with a one-sentence summary of what the overall command does.
            3. Break down each component: the main command, every flag/option, pipes, \
               redirections, subshells, and glob patterns.
            4. Describe side effects: files created, modified, or deleted; \
               environment changes; network access.
            5. Flag hazards explicitly — commands that overwrite, delete, or have \
               irreversible effects must be clearly called out.
            6. If a simpler or safer alternative exists, mention it briefly.

            Tone: precise but approachable. Use short paragraphs or bullets as needed. \
            Prefer plain language over man-page jargon. Never execute the user's command \
            itself — only gather context via help flags and man pages.
            """,
            userPromptTemplate: "Explain the shell command the user provided."
        )
    }

    func process(response: AIResponse) async throws -> SkillResult {
        SkillResult(output: response.text, metadata: [:], usage: response.usage)
    }
}
#endif
