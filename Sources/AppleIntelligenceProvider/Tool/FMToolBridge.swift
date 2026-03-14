#if canImport(FoundationModels)
import Foundation
import FoundationModels
import AIProviderKit

/// Bridges an `AIProviderKit.Tool` to the `FoundationModels.Tool` protocol.
///
/// `FMToolBridge` allows tools registered in `AIProviderKit` to be passed
/// natively to `LanguageModelSession`, so the on-device model can call them
/// directly during inference — no prompt injection needed.
///
/// The `Arguments` type is `FMJSONArguments`, which converts `GeneratedContent`
/// to `JSONValue` before forwarding to the original handler. The `Output` is
/// `String` (a JSON-encoded representation of the `JSONValue` result).
@available(iOS 26.0, macOS 26.0, *)
struct FMToolBridge: FoundationModels.Tool, Sendable {

    typealias Arguments = FMJSONArguments
    typealias Output    = String

    // MARK: - FoundationModels.Tool

    let name: String
    let description: String
    let parameters: GenerationSchema

    // MARK: - Private

    private let handler: @Sendable (JSONValue) async throws -> JSONValue

    // MARK: - Init

    /// Creates a bridge from the components of an `AIProviderKit.Tool`.
    ///
    /// - Throws: `GenerationSchema.SchemaError` if the `inputSchema` cannot be
    ///   converted to a valid `GenerationSchema` (e.g. duplicate property names).
    init(
        name: String,
        description: String,
        inputSchema: JSONSchema,
        handler: @escaping @Sendable (JSONValue) async throws -> JSONValue
    ) throws {
        self.name        = name
        self.description = description
        self.handler     = handler

        let dynamic = FMSchemaMapper().map(inputSchema)
        self.parameters  = try GenerationSchema(root: dynamic, dependencies: [])
    }

    // MARK: - FoundationModels.Tool

    func call(arguments: FMJSONArguments) async throws -> String {
        let result = try await handler(arguments.jsonValue)
        guard let json = String(data: try JSONEncoder().encode(result), encoding: .utf8) else {
            return "null"
        }
        return json
    }
}
#endif
