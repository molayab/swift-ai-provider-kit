/// A provider-agnostic JSON Schema description for tool input validation.
///
/// Uses an `indirect enum` to support recursive schemas (arrays, objects).
///
/// ```swift
/// let schema = JSONSchema.object(
///     properties: ["city": .string(description: "City name")],
///     required: ["city"]
/// )
/// ```
public indirect enum JSONSchema: Sendable, Equatable {
    case string(description: String? = nil)
    case integer(description: String? = nil)
    case number(description: String? = nil)
    case boolean(description: String? = nil)
    case array(items: JSONSchema, description: String? = nil)
    case object(
        properties: [String: JSONSchema] = [:],
        required: [String]? = nil,
        description: String? = nil
    )
}

// MARK: - Encodable (only encoding needed — schemas are sent to providers, not decoded)

extension JSONSchema: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type, description, properties, required, items
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let description):
            try container.encode("string", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)

        case .integer(let description):
            try container.encode("integer", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)

        case .number(let description):
            try container.encode("number", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)

        case .boolean(let description):
            try container.encode("boolean", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)

        case .array(let items, let description):
            try container.encode("array", forKey: .type)
            try container.encode(items, forKey: .items)
            try container.encodeIfPresent(description, forKey: .description)

        case .object(let properties, let required, let description):
            try container.encode("object", forKey: .type)
            if !properties.isEmpty {
                try container.encode(properties, forKey: .properties)
            }
            try container.encodeIfPresent(required, forKey: .required)
            try container.encodeIfPresent(description, forKey: .description)
        }
    }
}
