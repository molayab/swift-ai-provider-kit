import AIProviderKit
import AIProviderTools
import Testing

// NOTE: Execution tests are intentionally omitted for CalendarTool.
// EKEventStore requires explicit user permission (calendar entitlement +
// runtime authorisation prompt) that cannot be granted in a headless test
// environment. Because EKEventStore is a concrete class with no protocol
// seam, injecting a mock requires a wrapper abstraction that has not yet
// been built. Until that abstraction exists these tests cover only tool
// metadata and schema correctness. Tracked in Documentation/Issues/.
@Suite("CalendarTool")
struct CalendarToolTests {

    // MARK: - ToolGroup

    @Test("all contains exactly two tools")
    func allCount() {
        #expect(CalendarTool.all.count == 2)
    }

    @Test("all tool names are unique")
    func allNamesAreUnique() {
        let names = CalendarTool.all.map(\.name)
        #expect(Set(names).count == names.count)
    }

    // MARK: - listEvents metadata

    @Test("listEvents has correct name")
    func listEventsName() {
        #expect(CalendarTool.listEvents.name == "list_calendar_events")
    }

    @Test("listEvents schema has daysAhead and calendarName properties")
    func listEventsSchema() {
        // given
        let schema: JSONSchema = CalendarTool.listEvents.inputSchema

        // then
        guard case .object(let properties, _, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(properties["daysAhead"] != nil)
        #expect(properties["calendarName"] != nil)
    }

    @Test("listEvents schema has no required fields")
    func listEventsNoRequiredFields() {
        // given
        let schema: JSONSchema = CalendarTool.listEvents.inputSchema

        // then
        guard case .object(_, let required, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(required == nil || required?.isEmpty == true)
    }

    // MARK: - createEvent metadata

    @Test("createEvent has correct name")
    func createEventName() {
        #expect(CalendarTool.createEvent.name == "create_calendar_event")
    }

    @Test("createEvent schema requires title, startDate, endDate")
    func createEventRequiredFields() {
        // given
        let schema: JSONSchema = CalendarTool.createEvent.inputSchema

        // then
        guard case .object(_, let required, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(required?.contains("title") == true)
        #expect(required?.contains("startDate") == true)
        #expect(required?.contains("endDate") == true)
    }

    @Test("createEvent schema has optional notes and calendarName")
    func createEventOptionalFields() {
        // given
        let schema: JSONSchema = CalendarTool.createEvent.inputSchema

        // then
        guard case .object(let properties, _, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(properties["notes"] != nil)
        #expect(properties["calendarName"] != nil)
    }
}
