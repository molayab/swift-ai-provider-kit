#if canImport(FoundationModels)
import FoundationModels
import AIProviderKit

/// Converts an `AIProviderKit.JSONSchema` to a `FoundationModels.DynamicGenerationSchema`.
///
/// This allows tool input schemas defined with `JSONSchema` to be passed natively
/// to `LanguageModelSession` as typed `GenerationSchema` parameters.
@available(iOS 26.0, macOS 26.0, *)
struct FMSchemaMapper: Sendable {

    /// Maps a `JSONSchema` to a `DynamicGenerationSchema` with the given root name.
    func map(_ schema: JSONSchema, name: String = "Arguments") -> DynamicGenerationSchema {
        switch schema {
        case .string:
            return DynamicGenerationSchema(type: String.self)
        case .integer:
            return DynamicGenerationSchema(type: Int.self)
        case .number:
            return DynamicGenerationSchema(type: Double.self)
        case .boolean:
            return DynamicGenerationSchema(type: Bool.self)
        case .array(let items, _):
            return DynamicGenerationSchema(arrayOf: map(items))
        case .object(let properties, let required, let description):
            let props = properties.map { key, valueSchema in
                DynamicGenerationSchema.Property(
                    name: key,
                    description: schemaDescription(valueSchema),
                    schema: map(valueSchema, name: key),
                    isOptional: !(required?.contains(key) ?? false)
                )
            }
            return DynamicGenerationSchema(name: name, description: description, properties: props)
        }
    }

    // MARK: - Private

    /// Extracts the `description` associated value that every `JSONSchema` case carries.
    private func schemaDescription(_ schema: JSONSchema) -> String? {
        switch schema {
        case .string(let desc): return desc
        case .integer(let desc): return desc
        case .number(let desc): return desc
        case .boolean(let desc): return desc
        case .array(_, let desc): return desc
        case .object(_, _, let desc): return desc
        }
    }
}
#endif
