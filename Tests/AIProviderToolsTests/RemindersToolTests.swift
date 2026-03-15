import AIProviderKit
import AIProviderTools
import Testing

// NOTE: Execution tests are intentionally omitted for RemindersTool.
// EKEventStore requires explicit user permission (reminders entitlement +
// runtime authorisation prompt) that cannot be granted in a headless test
// environment. Because EKEventStore is a concrete class with no protocol
// seam, injecting a mock requires a wrapper abstraction that has not yet
// been built. Until that abstraction exists these tests cover only tool
// metadata and schema correctness. Tracked in Documentation/Issues/.
@Suite("RemindersTool")
struct RemindersToolTests {

    // MARK: - ToolGroup

    @Test("all contains exactly two tools")
    func allCount() {
        #expect(RemindersTool.all.count == 2)
    }

    @Test("all tool names are unique")
    func allNamesAreUnique() {
        let names = RemindersTool.all.map(\.name)
        #expect(Set(names).count == names.count)
    }

    // MARK: - listReminders metadata

    @Test("listReminders has correct name")
    func listRemindersName() {
        #expect(RemindersTool.listReminders.name == "list_reminders")
    }

    @Test("listReminders schema has listName and limit properties")
    func listRemindersSchema() {
        // given
        let schema: JSONSchema = RemindersTool.listReminders.inputSchema

        // then
        guard case .object(let properties, _, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(properties["listName"] != nil)
        #expect(properties["limit"] != nil)
    }

    @Test("listReminders schema has no required fields")
    func listRemindersNoRequiredFields() {
        // given
        let schema: JSONSchema = RemindersTool.listReminders.inputSchema

        // then
        guard case .object(_, let required, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(required == nil || required?.isEmpty == true)
    }

    // MARK: - createReminder metadata

    @Test("createReminder has correct name")
    func createReminderName() {
        #expect(RemindersTool.createReminder.name == "create_reminder")
    }

    @Test("createReminder schema requires title")
    func createReminderRequiredFields() {
        // given
        let schema: JSONSchema = RemindersTool.createReminder.inputSchema

        // then
        guard case .object(_, let required, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(required?.contains("title") == true)
    }

    @Test("createReminder schema has optional notes, dueDate, listName")
    func createReminderOptionalFields() {
        // given
        let schema: JSONSchema = RemindersTool.createReminder.inputSchema

        // then
        guard case .object(let properties, _, _) = schema else {
            Issue.record("Expected object schema")
            return
        }
        #expect(properties["notes"] != nil)
        #expect(properties["dueDate"] != nil)
        #expect(properties["listName"] != nil)
    }
}
