/// Example: Streaming response with SwiftUI
///
/// Demonstrates:
///   - Using `client.stream(_:)` for live token-by-token output
///   - Integrating streaming into a SwiftUI `@Observable` view model

import SwiftUI
import AIProviderKit
import ClaudeProvider

// MARK: - ViewModel

@Observable
final class ChatViewModel {
    var output: String = ""
    var isStreaming: Bool = false
    var error: String?

    private let client: AIClient

    init() {
        let provider = ClaudeProvider(
            authorization: APIKeyAuthorization(apiKey: "sk-ant-YOUR_KEY_HERE")
        )
        self.client = AIClient(provider: provider)
    }

    func stream(_ prompt: String) async {
        output = ""
        isStreaming = true
        error = nil

        do {
            let request = try AIRequestBuilder()
                .model(.claudeSonnet4)
                .addMessage(.user(text: prompt))
                .build()

            for try await event in await client.stream(request) {
                switch event {
                case .textDelta(let chunk):
                    await MainActor.run { output += chunk }
                case .message(let response):
                    print("Finished — tokens used: \(response.usage.totalTokens)")
                default:
                    break
                }
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }

        isStreaming = false
    }
}

// MARK: - SwiftUI View

struct StreamingChatView: View {

    @State private var viewModel = ChatViewModel()
    @State private var prompt = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                Text(viewModel.output)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            if let error = viewModel.error {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            HStack {
                TextField("Ask something…", text: $prompt)
                    .textFieldStyle(.roundedBorder)

                Button("Send") {
                    let text = prompt
                    prompt = ""
                    Task { await viewModel.stream(text) }
                }
                .disabled(viewModel.isStreaming || prompt.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Streaming Chat")
    }
}
