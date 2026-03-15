import Testing
import AIProviderKit
import AIProviderTools

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
