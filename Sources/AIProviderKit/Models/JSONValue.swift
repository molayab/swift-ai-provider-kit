import Foundation

/// A type-safe, `Sendable` representation of any JSON value.
///
/// Used for tool input/output where the schema is provider-defined.
@frozen
public enum JSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case integer(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - CustomStringConvertible

extension JSONValue: CustomStringConvertible {
    public var description: String {
        (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "null"
    }
}

// MARK: - Codable (manual — required for heterogeneous enum)

extension JSONValue: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Int.self) { self = .integer(value); return }
        if let value = try? container.decode(Double.self) { self = .double(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        throw DecodingError.typeMismatch(
            JSONValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON type")
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:               try container.encodeNil()
        case .bool(let value):    try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .double(let value):  try container.encode(value)
        case .string(let value):  try container.encode(value)
        case .array(let value):   try container.encode(value)
        case .object(let value):  try container.encode(value)
        }
    }
}

// MARK: - Literals

extension JSONValue: ExpressibleByNilLiteral { public init(nilLiteral: ()) { self = .null } }
extension JSONValue: ExpressibleByBooleanLiteral { public init(booleanLiteral value: Bool) { self = .bool(value) } }
extension JSONValue: ExpressibleByIntegerLiteral { public init(integerLiteral value: Int) { self = .integer(value) } }
extension JSONValue: ExpressibleByFloatLiteral { public init(floatLiteral value: Double) { self = .double(value) } }
extension JSONValue: ExpressibleByStringLiteral { public init(stringLiteral value: String) { self = .string(value) } }
extension JSONValue: ExpressibleByArrayLiteral { public init(arrayLiteral elements: JSONValue...) { self = .array(elements) } }
extension JSONValue: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = JSONValue
    public init(dictionaryLiteral elements: (String, JSONValue)...) { self = .object(.init(uniqueKeysWithValues: elements)) }
}

// MARK: - Accessors

public extension JSONValue {
    var stringValue: String? { guard case .string(let value) = self else { return nil }; return value }
    var intValue: Int? { guard case .integer(let value) = self else { return nil }; return value }
    // swiftlint:disable:next discouraged_optional_boolean
    var boolValue: Bool? { guard case .bool(let value) = self else { return nil }; return value }
    var isNull: Bool { if case .null = self { return true }; return false }

    var doubleValue: Double? {
        switch self {
        case .double(let value):  return value
        case .integer(let value): return Double(value)
        default:                  return nil
        }
    }

    subscript(key: String) -> JSONValue? {
        guard case .object(let dict) = self else { return nil }
        return dict[key]
    }

    subscript(index: Int) -> JSONValue? {
        guard case .array(let array) = self, array.indices.contains(index) else { return nil }
        return array[index]
    }
}
