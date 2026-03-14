import PackagePlugin
import Foundation

/// SPM command plugin that builds and runs the `IntegrationTests` executable.
///
/// Invoke with:
///   ANTHROPIC_API_KEY=sk-ant-... swift package integration-tests claude
///   swift package integration-tests apple-intelligence
///   ANTHROPIC_API_KEY=sk-ant-... swift package integration-tests all
@main
struct RunIntegrationTestsPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(named: "IntegrationTests")

        let process = Process()
        process.executableURL = tool.url
        process.arguments = arguments
        // Forward the caller's full environment so ANTHROPIC_API_KEY and any
        // other provider secrets are available to the test runner.
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
