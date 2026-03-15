import AIProviderKit
import AIProviderTools
import Foundation
import Testing

@Suite("CurrentTimeTool")
struct CurrentTimeToolTests {

    // MARK: - ToolGroup

    @Test("all contains exactly one tool")
    func allCount() {
        #expect(CurrentTimeTool.all.count == 1)
    }

    @Test("tool returns the same instance as all[0]")
    func toolMatchesAll() throws {
        #expect(try CurrentTimeTool.tool().name == CurrentTimeTool.all[0].name)
    }

    // MARK: - Metadata

    @Test("tool has correct name")
    func name() {
        #expect(CurrentTimeTool.currentTime.name == "get_current_time")
    }

    @Test("tool has non-empty description")
    func descriptionIsNonEmpty() {
        #expect(!CurrentTimeTool.currentTime.description.isEmpty)
    }

    @Test("input schema has optional format property")
    func inputSchemaFormatProperty() {
        // given
        let schema: JSONSchema = CurrentTimeTool.currentTime.inputSchema

        // then
        guard case .object(let properties, _, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(properties["format"] != nil)
    }

    // MARK: - Execution

    @Test("default execution returns iso8601 and timezone keys")
    func defaultOutput() async throws {
        // given
        let input: JSONValue = .object([:])

        // when
        let result = try await CurrentTimeTool.currentTime.execute(with: input)

        // then
        guard case .object(let dict) = result else {
            Issue.record("Expected object result")
            return
        }
        #expect(dict["iso8601"] != nil)
        #expect(dict["timezone"] != nil)
    }

    @Test("human format returns a non-empty string")
    func humanFormat() async throws {
        // given
        let input: JSONValue = .object(["format": .string("human")])

        // when
        let result = try await CurrentTimeTool.currentTime.execute(with: input)

        // then
        guard case .string(let text) = result else {
            Issue.record("Expected string result for human format")
            return
        }
        #expect(!text.isEmpty)
    }

    @Test("iso8601 value is parseable as a date")
    func iso8601ValueIsParseable() async throws {
        // given
        let input: JSONValue = .object([:])

        // when
        let result = try await CurrentTimeTool.currentTime.execute(with: input)

        // then
        guard case .object(let dict) = result,
              case .string(let isoString) = dict["iso8601"] else {
            Issue.record("Expected iso8601 string in result")
            return
        }
        #expect(ISO8601DateFormatter().date(from: isoString) != nil)
    }
}
