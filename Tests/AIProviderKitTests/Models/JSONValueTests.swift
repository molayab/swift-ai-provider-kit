@testable import AIProviderKit
import Foundation
import Testing

@Suite("JSONValue")
struct JSONValueTests {

    // MARK: - Literal Construction

    @Test("string literal creates .string case")
    func stringLiteral_createsStringCase() {
        // Given
        let value: JSONValue = "hello"

        // When
        let result = value.stringValue

        // Then
        #expect(result == "hello")
    }

    @Test("integer literal creates .integer case")
    func integerLiteral_createsIntegerCase() {
        // Given
        let value: JSONValue = 42

        // When
        let result = value.intValue

        // Then
        #expect(result == 42)
    }

    @Test("float literal creates .double case")
    func floatLiteral_createsDoubleCase() {
        // Given
        let value: JSONValue = 3.14

        // When
        let result = value.doubleValue

        // Then
        #expect(result == 3.14)
    }

    @Test("boolean literal creates .bool case")
    func boolLiteral_createsBoolCase() {
        // Given
        let value: JSONValue = true

        // When
        let result = value.boolValue

        // Then
        #expect(result == true)
    }

    @Test("nil literal creates .null case")
    func nilLiteral_createsNullCase() {
        // Given
        let value: JSONValue = nil

        // When / Then
        #expect(value.isNull)
    }

    @Test("array literal creates .array case")
    func arrayLiteral_createsArrayCase() {
        // Given
        let value: JSONValue = [1, 2, 3]

        // When
        let first = value[0]

        // Then
        #expect(first?.intValue == 1)
    }

    @Test("dictionary literal creates .object case")
    func dictionaryLiteral_createsObjectCase() {
        // Given
        let value: JSONValue = ["name": "Alice", "age": 30]

        // When
        let name = value["name"]

        // Then
        #expect(name?.stringValue == "Alice")
    }

    // MARK: - Codable Round-Trip

    @Test("encodes and decodes string value")
    func codableRoundTrip_string() throws {
        // Given
        let original: JSONValue = "hello"

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        // Then
        #expect(decoded == original)
    }

    @Test("encodes and decodes integer value")
    func codableRoundTrip_integer() throws {
        // Given
        let original: JSONValue = 42

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        // Then
        #expect(decoded == original)
    }

    @Test("encodes and decodes double value")
    func codableRoundTrip_double() throws {
        // Given
        let original: JSONValue = 3.14

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        // Then
        #expect(decoded == original)
    }

    @Test("encodes and decodes bool value")
    func codableRoundTrip_bool() throws {
        // Given
        let original: JSONValue = true

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        // Then
        #expect(decoded == original)
    }

    @Test("encodes and decodes null value")
    func codableRoundTrip_null() throws {
        // Given
        let original: JSONValue = nil

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        // Then
        #expect(decoded == original)
    }

    @Test("encodes and decodes array value")
    func codableRoundTrip_array() throws {
        // Given
        let original: JSONValue = [1, "two", true]

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        // Then
        #expect(decoded == original)
    }

    @Test("encodes and decodes object value")
    func codableRoundTrip_object() throws {
        // Given
        let original: JSONValue = ["key": "value", "count": 5]

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        // Then
        #expect(decoded == original)
    }

    // MARK: - Subscript Access

    @Test("object subscript returns value for existing key")
    func objectSubscript_existingKey_returnsValue() {
        // Given
        let value: JSONValue = ["name": "Bob"]

        // When
        let result = value["name"]

        // Then
        #expect(result == .string("Bob"))
    }

    @Test("object subscript returns nil for missing key")
    func objectSubscript_missingKey_returnsNil() {
        // Given
        let value: JSONValue = ["name": "Bob"]

        // When
        let result = value["age"]

        // Then
        #expect(result == nil)
    }

    @Test("object subscript returns nil for non-object")
    func objectSubscript_nonObject_returnsNil() {
        // Given
        let value: JSONValue = "just a string"

        // When
        let result = value["key"]

        // Then
        #expect(result == nil)
    }

    @Test("array subscript returns value at valid index")
    func arraySubscript_validIndex_returnsValue() {
        // Given
        let value: JSONValue = [10, 20, 30]

        // When
        let result = value[1]

        // Then
        #expect(result?.intValue == 20)
    }

    @Test("array subscript returns nil for out-of-bounds index")
    func arraySubscript_outOfBounds_returnsNil() {
        // Given
        let value: JSONValue = [10, 20]

        // When
        let result = value[5]

        // Then
        #expect(result == nil)
    }

    @Test("array subscript returns nil for non-array")
    func arraySubscript_nonArray_returnsNil() {
        // Given
        let value: JSONValue = "not an array"

        // When
        let result = value[0]

        // Then
        #expect(result == nil)
    }

    // MARK: - Typed Accessors

    @Test("stringValue returns nil for non-string")
    func stringValue_nonString_returnsNil() {
        // Given
        let value: JSONValue = 42

        // When
        let result = value.stringValue

        // Then
        #expect(result == nil)
    }

    @Test("intValue returns nil for non-integer")
    func intValue_nonInteger_returnsNil() {
        // Given
        let value: JSONValue = "hello"

        // When
        let result = value.intValue

        // Then
        #expect(result == nil)
    }

    @Test("boolValue returns nil for non-bool")
    func boolValue_nonBool_returnsNil() {
        // Given
        let value: JSONValue = "hello"

        // When
        let result = value.boolValue

        // Then
        #expect(result == nil)
    }

    @Test("doubleValue returns value for double case")
    func doubleValue_doubleCase_returnsValue() {
        // Given
        let value: JSONValue = 2.5

        // When
        let result = value.doubleValue

        // Then
        #expect(result == 2.5)
    }

    @Test("doubleValue returns casted value for integer case")
    func doubleValue_integerCase_returnsCastedValue() {
        // Given
        let value: JSONValue = 10

        // When
        let result = value.doubleValue

        // Then
        #expect(result == 10.0)
    }

    @Test("doubleValue returns nil for non-numeric case")
    func doubleValue_nonNumeric_returnsNil() {
        // Given
        let value: JSONValue = "not a number"

        // When
        let result = value.doubleValue

        // Then
        #expect(result == nil)
    }

    // MARK: - isNull

    @Test("isNull returns true for null case")
    func isNull_nullCase_returnsTrue() {
        // Given
        let value: JSONValue = .null

        // When / Then
        #expect(value.isNull)
    }

    @Test("isNull returns false for non-null case")
    func isNull_nonNullCase_returnsFalse() {
        // Given
        let value: JSONValue = "something"

        // When / Then
        #expect(!value.isNull)
    }

    // MARK: - CustomStringConvertible

    @Test("description returns JSON representation for string")
    func description_string_returnsJSON() {
        // Given
        let value: JSONValue = "hello"

        // When
        let result = value.description

        // Then
        #expect(result.contains("hello"))
    }

    @Test("description returns JSON representation for null")
    func description_null_returnsNull() {
        // Given
        let value: JSONValue = .null

        // When
        let result = value.description

        // Then
        #expect(result == "null")
    }

    // MARK: - Equatable

    @Test("identical values are equal")
    func equatable_identicalValues_areEqual() {
        // Given
        let lhs: JSONValue = ["key": "value"]
        let rhs: JSONValue = ["key": "value"]

        // When / Then
        #expect(lhs == rhs)
    }

    @Test("different values are not equal")
    func equatable_differentValues_areNotEqual() {
        // Given
        let lhs: JSONValue = "hello"
        let rhs: JSONValue = "world"

        // When / Then
        #expect(lhs != rhs)
    }
}
