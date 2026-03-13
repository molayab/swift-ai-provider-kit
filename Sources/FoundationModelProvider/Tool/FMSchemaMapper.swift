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
                    description: nil,
                    schema: map(valueSchema, name: key),
                    isOptional: !(required?.contains(key) ?? false)
                )
            }
            return DynamicGenerationSchema(name: name, description: description, properties: props)
        }
    }
}
#endif
