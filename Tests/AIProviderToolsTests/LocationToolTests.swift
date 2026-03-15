import AIProviderKit
import AIProviderTools
import Testing

@Suite("LocationTool")
struct LocationToolTests {

    // MARK: - ToolGroup

    @Test("all contains exactly one tool")
    func allCount() {
        #expect(LocationTool.all.count == 1)
    }

    @Test("tool returns the same instance as all[0]")
    func toolMatchesAll() {
        #expect(LocationTool.tool.name == LocationTool.all[0].name)
    }

    // MARK: - Metadata

    @Test("tool has correct name")
    func name() {
        #expect(LocationTool.make().name == "get_current_location")
    }

    @Test("tool has non-empty description")
    func descriptionIsNonEmpty() {
        #expect(!LocationTool.make().description.isEmpty)
    }

    @Test("input schema has includeAddress property")
    func inputSchemaIncludeAddress() {
        // given
        let schema: JSONSchema = LocationTool.make().inputSchema

        // then
        guard case .object(let properties, _, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(properties["includeAddress"] != nil)
    }

    @Test("input schema has no required fields")
    func inputSchemaNoRequiredFields() {
        // given
        let schema: JSONSchema = LocationTool.make().inputSchema

        // then
        guard case .object(_, let required, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(required == nil || required?.isEmpty == true)
    }

    @Test("make() produces instances with consistent metadata")
    func makeProducesConsistentMetadata() {
        let first = LocationTool.make()
        let second = LocationTool.make()
        #expect(first.name == second.name)
        #expect(first.description == second.description)
    }
}
