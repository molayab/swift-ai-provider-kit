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
        let c = try decoder.singleValueContainer()
        if c.decodeNil()                                 { self = .null;    return }
        if let v = try? c.decode(Bool.self)              { self = .bool(v); return }
        if let v = try? c.decode(Int.self)               { self = .integer(v); return }
        if let v = try? c.decode(Double.self)            { self = .double(v); return }
        if let v = try? c.decode(String.self)            { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self)       { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.typeMismatch(
            JSONValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON type")
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null:            try c.encodeNil()
        case .bool(let v):     try c.encode(v)
        case .integer(let v):  try c.encode(v)
        case .double(let v):   try c.encode(v)
        case .string(let v):   try c.encode(v)
        case .array(let v):    try c.encode(v)
        case .object(let v):   try c.encode(v)
        }
    }
}

// MARK: - Literals

extension JSONValue: ExpressibleByNilLiteral       { public init(nilLiteral: ())               { self = .null } }
extension JSONValue: ExpressibleByBooleanLiteral   { public init(booleanLiteral v: Bool)        { self = .bool(v) } }
extension JSONValue: ExpressibleByIntegerLiteral   { public init(integerLiteral v: Int)         { self = .integer(v) } }
extension JSONValue: ExpressibleByFloatLiteral     { public init(floatLiteral v: Double)        { self = .double(v) } }
extension JSONValue: ExpressibleByStringLiteral    { public init(stringLiteral v: String)       { self = .string(v) } }
extension JSONValue: ExpressibleByArrayLiteral     { public init(arrayLiteral e: JSONValue...)  { self = .array(e) } }
extension JSONValue: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = JSONValue
    public init(dictionaryLiteral e: (String, JSONValue)...) { self = .object(.init(uniqueKeysWithValues: e)) }
}

// MARK: - Accessors

public extension JSONValue {
    var stringValue: String?  { guard case .string(let v)  = self else { return nil }; return v }
    var intValue: Int?        { guard case .integer(let v) = self else { return nil }; return v }
    var boolValue: Bool?      { guard case .bool(let v)    = self else { return nil }; return v }
    var isNull: Bool          { if case .null = self { return true }; return false }

    var doubleValue: Double? {
        switch self {
        case .double(let v):  return v
        case .integer(let v): return Double(v)
        default:              return nil
        }
    }

    subscript(key: String) -> JSONValue? {
        guard case .object(let d) = self else { return nil }
        return d[key]
    }

    subscript(index: Int) -> JSONValue? {
        guard case .array(let a) = self, a.indices.contains(index) else { return nil }
        return a[index]
    }
}
