/// Example: Logging setup — system log + in-app viewer
///
/// Demonstrates:
///   - Enabling `AILogStore` for in-app capture at startup
///   - Attaching `AILogger` to the provider and client
///   - Presenting `AILogView` in a settings/debug sheet

import SwiftUI
import AIProviderKit
import AIProviderKitUI
import ClaudeProvider

// MARK: - App entry point

@main
struct ExampleApp: App {

    init() {
        // Enable in-app log capture. Without this, logs only go to Console.app.
        AILogStore.shared = AILogStore()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Client setup

extension AIClient {
    static let shared: AIClient = {
        let logger = AILogger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
            category: "ai"
        )
        let provider = ClaudeProvider(
            authorization: APIKeyAuthorization(apiKey: "sk-ant-YOUR_KEY_HERE"),
            logger: logger
        )
        return AIClient(provider: provider, logger: logger)
    }()
}

// MARK: - View with debug log sheet

struct ContentView: View {

    @State private var showLogs = false

    var body: some View {
        NavigationStack {
            Text("App Content")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showLogs = true
                        } label: {
                            Image(systemName: "ladybug")
                        }
                    }
                }
                .sheet(isPresented: $showLogs) {
                    AILogView(store: AILogStore.shared ?? AILogStore())
                }
        }
    }
}
