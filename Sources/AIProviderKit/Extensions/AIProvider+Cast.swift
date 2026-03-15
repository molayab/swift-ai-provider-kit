/// Convenience extensions for casting an `AIProvider` to a concrete type.
public extension AIProvider {

    /// Casts the provider to a concrete type and returns it.
    ///
    /// Use this to access provider-specific APIs without breaking the abstraction at the
    /// `AIClient` layer.
    ///
    /// ```swift
    /// // Hold a typed reference for repeated use
    /// let openAI = try client.provider.castAs(OpenAIProvider.self)
    /// let models = try await openAI.listModels()
    /// ```
    ///
    /// - Throws: `AIError.providerTypeMismatch(expected:actual:)` if the underlying provider
    ///   is not an instance of `T`.
    func castAs<T: AIProvider>(_ type: T.Type) throws(AIError) -> T {
        guard let concrete = self as? T else {
            throw AIError.providerTypeMismatch(
                expected: String(describing: T.self),
                actual: String(describing: Swift.type(of: self))
            )
        }
        return concrete
    }
}
