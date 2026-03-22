import AIProviderKit
import Foundation

/// Centralised constants for the OpenAI provider.
///
/// Add new chat-capable model prefixes here when OpenAI introduces new model families
/// (e.g., a future `"o5"` or `"gpt-5"` series) without touching any other file.
enum OpenAIConstants {

    // MARK: - Endpoints

    /// Base URL for the Chat Completions API.
    static let chatCompletionsURL: URL? = makeURL("https://api.openai.com/v1/chat/completions")

    /// Base URL for the Models listing API.
    static let modelsURL: URL? = makeURL("https://api.openai.com/v1/models")

    // MARK: - Chat model prefixes

    /// Identifier prefixes that indicate a model is compatible with the Chat Completions API.
    ///
    /// Extend this list when OpenAI adds a new model family.
    static let chatModelPrefixes: [String] = [
        "gpt-",       // GPT-4o, GPT-4-turbo, GPT-3.5-turbo, …
        "o1",         // o1, o1-mini, o1-preview
        "o3",         // o3, o3-mini
        "o4",         // o4-mini, …
        "chatgpt-"    // chatgpt-4o-latest, …
    ]

    // MARK: - Non-chat model prefixes

    /// Identifier prefixes for model types that are NOT compatible with Chat Completions.
    ///
    /// These are excluded even when they match a chat prefix, preventing accidental inclusion
    /// of embedding, audio, or image-generation models.
    static let excludedModelPrefixes: [String] = [
        "text-embedding",   // text-embedding-3-large, text-embedding-3-small, …
        "whisper",          // whisper-1
        "dall-e",           // dall-e-2, dall-e-3
        "tts-",             // tts-1, tts-1-hd
        "davinci",          // Legacy completion models
        "babbage",          // Legacy completion models
        "ada",              // Legacy completion models
        "curie"             // Legacy completion models
    ]

    // MARK: - Private helpers

    private static func makeURL(_ string: String) -> URL? {
        URL(string: string)
    }
}
