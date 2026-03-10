/// A result builder for constructing `[ContentBlock]` arrays declaratively.
///
/// Used by `Message.user { … }` and `Message.assistant { … }` factory methods.
@resultBuilder
public enum ContentBlockBuilder {

    public static func buildBlock(_ components: ContentBlock...) -> [ContentBlock] {
        components
    }

    public static func buildOptional(_ component: [ContentBlock]?) -> [ContentBlock] {
        component ?? []
    }

    public static func buildEither(first component: [ContentBlock]) -> [ContentBlock] {
        component
    }

    public static func buildEither(second component: [ContentBlock]) -> [ContentBlock] {
        component
    }

    public static func buildArray(_ components: [[ContentBlock]]) -> [ContentBlock] {
        components.flatMap { $0 }
    }
}
