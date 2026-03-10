/// A result builder for constructing `[Message]` arrays declaratively.
///
/// Used by `AIRequestBuilder.conversation { … }`.
///
/// ```swift
/// builder.conversation {
///     Message.system("You are a helpful assistant.")
///     Message.user(text: "Hello!")
///     Message.assistant(text: "Hi there!")
/// }
/// ```
@resultBuilder
public enum ConversationBuilder {

    public static func buildBlock(_ components: Message...) -> [Message] {
        components
    }

    public static func buildOptional(_ component: [Message]?) -> [Message] {
        component ?? []
    }

    public static func buildEither(first component: [Message]) -> [Message] {
        component
    }

    public static func buildEither(second component: [Message]) -> [Message] {
        component
    }

    public static func buildArray(_ components: [[Message]]) -> [Message] {
        components.flatMap { $0 }
    }
}
