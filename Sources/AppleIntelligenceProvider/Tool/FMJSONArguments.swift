#if canImport(FoundationModels)
import FoundationModels
import AIProviderKit

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
        case .bool(let b):
            return .bool(b)
        case .number(let d):
            // Preserve integer precision when the number is exactly representable as Int.
            if let intValue = Int(exactly: d) {
                return .integer(intValue)
            }
            return .double(d)
        case .string(let s):
            return .string(s)
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
