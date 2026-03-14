@testable import AIProviderKit
import Foundation
import Testing

@Suite("JSONSchema")
struct JSONSchemaTests {

    // MARK: - Helpers

    private func encodeToJSON(_ schema: JSONSchema) throws -> [String: Any] {
        let data = try JSONEncoder().encode(schema)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try #require(json)
    }

    // MARK: - String

    @Test("string schema encodes with type string")
    func string_encodesTypeString() throws {
        // Given
        let schema = JSONSchema.string(description: "A name")

        // When
        let json = try encodeToJSON(schema)

        // Then
        #expect(json["type"] as? String == "string")
        #expect(json["description"] as? String == "A name")
    }

    @Test("string schema omits description when nil")
    func string_omitsDescriptionWhenNil() throws {
        // Given
        let schema = JSONSchema.string()

        // When
        let json = try encodeToJSON(schema)

        // Then
        #expect(json["type"] as? String == "string")
        #expect(json["description"] == nil)
    }

    // MARK: - Integer

    @Test("integer schema encodes with type integer")
    func integer_encodesTypeInteger() throws {
        // Given
        let schema = JSONSchema.integer(description: "An age")

        // When
        let json = try encodeToJSON(schema)

        // Then
        #expect(json["type"] as? String == "integer")
        #expect(json["description"] as? String == "An age")
    }

    // MARK: - Number

    @Test("number schema encodes with type number")
    func number_encodesTypeNumber() throws {
        // Given
        let schema = JSONSchema.number(description: "A temperature")

        // When
        let json = try encodeToJSON(schema)

        // Then
        #expect(json["type"] as? String == "number")
        #expect(json["description"] as? String == "A temperature")
    }

    // MARK: - Boolean

    @Test("boolean schema encodes with type boolean")
    func boolean_encodesTypeBoolean() throws {
        // Given
        let schema = JSONSchema.boolean()

        // When
        let json = try encodeToJSON(schema)

        // Then
        #expect(json["type"] as? String == "boolean")
    }

    // MARK: - Array

    @Test("array schema encodes with type array and items")
    func array_encodesTypeArrayWithItems() throws {
        // Given
        let schema = JSONSchema.array(items: .string(), description: "List of names")

        // When
        let json = try encodeToJSON(schema)

        // Then
        #expect(json["type"] as? String == "array")
        #expect(json["description"] as? String == "List of names")
        let items = json["items"] as? [String: Any]
        #expect(items?["type"] as? String == "string")
    }

    // MARK: - Object

    @Test("object schema encodes with type object, properties, and required")
    func object_encodesTypeObjectWithPropertiesAndRequired() throws {
        // Given
        let schema = JSONSchema.object(
            properties: ["city": .string(description: "City name")],
            required: ["city"],
            description: "Location input"
        )

        // When
        let json = try encodeToJSON(schema)

        // Then
        #expect(json["type"] as? String == "object")
        #expect(json["description"] as? String == "Location input")
        #expect(json["required"] as? [String] == ["city"])
        let props = json["properties"] as? [String: Any]
        let cityProp = props?["city"] as? [String: Any]
        #expect(cityProp?["type"] as? String == "string")
    }

    @Test("object schema omits properties key when empty")
    func object_omitsPropertiesWhenEmpty() throws {
        // Given
        let schema = JSONSchema.object()

        // When
        let json = try encodeToJSON(schema)

        // Then
        #expect(json["type"] as? String == "object")
        #expect(json["properties"] == nil)
    }

    @Test("object schema omits required when nil")
    func object_omitsRequiredWhenNil() throws {
        // Given
        let schema = JSONSchema.object(properties: ["x": .integer()])

        // When
        let json = try encodeToJSON(schema)

        // Then
        #expect(json["required"] == nil)
    }

    // MARK: - Equatable

    @Test("identical schemas are equal")
    func equatable_identicalSchemas_areEqual() {
        // Given
        let lhs = JSONSchema.string(description: "test")
        let rhs = JSONSchema.string(description: "test")

        // When / Then
        #expect(lhs == rhs)
    }

    @Test("different schemas are not equal")
    func equatable_differentSchemas_areNotEqual() {
        // Given
        let lhs = JSONSchema.string()
        let rhs = JSONSchema.integer()

        // When / Then
        #expect(lhs != rhs)
    }
}
