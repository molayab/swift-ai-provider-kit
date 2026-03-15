import PackagePlugin
import Foundation

/// SPM command plugin that runs the `aipk test` subcommand.
///
/// Invoke with:
///   ANTHROPIC_API_KEY=sk-ant-... swift package integration-tests claude
///   OPENAI_API_KEY=sk-...       swift package integration-tests openai
///   swift package integration-tests apple-intelligence
///   ANTHROPIC_API_KEY=sk-... OPENAI_API_KEY=sk-... swift package integration-tests all
@main
struct RunIntegrationTestsPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(named: "runner")

        let process = Process()
        process.executableURL = tool.url
        // Prepend "test" so plugin arguments map to: aipk test <provider>
        process.arguments = ["test"] + arguments
        // Forward the caller's full environment so API keys and other provider
        // secrets are available to the test runner.
        process.environment = ProcessInfo.processInfo.environment

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw PluginError.failed(code: Int(process.terminationStatus))
        }
    }
}

private enum PluginError: Error, CustomStringConvertible {
    case failed(code: Int)

    var description: String {
        switch self {
        case .failed(let code):
            return "Integration tests exited with code \(code)"
        }
    }
}
