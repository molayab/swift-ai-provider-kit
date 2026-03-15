/// Convenience extensions for casting an `AIProvider` to a concrete type.
public extension AIProvider {

    /// Casts the provider to a concrete type and returns it.
    ///
    /// Use this to access provider-specific APIs without breaking the abstraction at the
    /// `AIClient` layer.
    ///
    /// ```swift
    /// // Cast and immediately call a provider-specific method
    /// let models = try await client.provider.castAs(OpenAIProvider.self).listModels()
    ///
    /// // Or hold a reference for repeated use
    /// let openAI = try client.provider.castAs(OpenAIProvider.self)
    /// ```
    ///
    /// - Throws: `AIError.providerUnsupported(capability:)` if the underlying provider is not `T`.
    func castAs<T: AIProvider>(_ type: T.Type) throws(AIError) -> T {
        guard let concrete = self as? T else {
            throw AIError.providerUnsupported(capability: .modelDiscovery)
        }
        return concrete
    }
}
