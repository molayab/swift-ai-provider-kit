#if canImport(FoundationModels)
import AIProviderKit
import FoundationModels

/// Bridges `FoundationModels.GeneratedContent` tool arguments to `AIProviderKit.JSONValue`.
///
/// Conforms to `ConvertibleFromGeneratedContent` so it can be used as the `Arguments`
/// associated type of `FMToolBridge`, satisfying the `FoundationModels.Tool` protocol.
@available(iOS 26.0, macOS 26.0, *)
struct FMJSONArguments: ConvertibleFromGeneratedContent, Sendable {

    let jsonValue: JSONValue

    init(_ content: GeneratedContent) throws {
        self.jsonValue = try FMJSONArguments.convert(content)
    }

    // MARK: - Private

    private static func convert(_ content: GeneratedContent) throws -> JSONValue {
        switch content.kind {
        case .null:
            return .null
        case .bool(let boolValue):
            return .bool(boolValue)
        case .number(let doubleValue):
            // Preserve integer precision when the number is exactly representable as Int.
            if let intValue = Int(exactly: doubleValue) {
                return .integer(intValue)
            }
            return .double(doubleValue)
        case .string(let stringValue):
            return .string(stringValue)
        case .array(let items):
            return .array(try items.map { try convert($0) })
        case .structure(let props, let orderedKeys):
            var obj: [String: JSONValue] = [:]
            for key in orderedKeys {
                if let child = props[key] {
                    obj[key] = try convert(child)
                }
            }
            return .object(obj)
        @unknown default:
            return .null
        }
    }
}
#endif
