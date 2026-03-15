import EventKit
import AIProviderKit

/// Ready-to-use `Tool`s for reading and creating reminders via EventKit.
///
/// ```swift
/// await client.toolRegistry.registerAll(RemindersTool.self)
/// ```
public enum RemindersTool: ToolGroup {

    /// All provided reminder tools.
    public static var all: [Tool] { [listReminders, createReminder] }

    // MARK: - List Reminders

    public static let listReminders = Tool(
        name: "list_reminders",
        description: "Returns incomplete reminders, optionally filtered by list name.",
        inputSchema: .object(
            properties: [
                "listName": .string(description: "Reminder list name to filter. Omit for all lists."),
                "limit": .integer(description: "Maximum number of reminders to return. Default: 20.")
            ]
        )
    ) { input async throws in
        let listName = input["listName"]?.stringValue
        let limit = input["limit"]?.intValue ?? 20

        let store = EKEventStore()
        try await store.requestFullAccessToReminders()

        let calendars = store.calendars(for: .reminder).filter {
            listName == nil || $0.title == listName
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars
        )

        let mapped: [JSONValue] = try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { results in
                let limited = (results ?? []).prefix(limit)
                let values: [JSONValue] = limited.map { reminder in
                    .object([
                        "title": .string(reminder.title ?? ""),
                        "list": .string(reminder.calendar.title),
                        "notes": reminder.notes.map { .string($0) } ?? .null,
                        "dueDate": reminder.dueDateComponents?.date.map {
                            .string(ISO8601DateFormatter().string(from: $0))
                        } ?? .null,
                        "priority": .integer(Int(reminder.priority))
                    ])
                }
                continuation.resume(returning: values)
            }
        }
        return .array(mapped)
    }

    // MARK: - Create Reminder

    public static let createReminder = Tool(
        name: "create_reminder",
        description: "Creates a new reminder.",
        inputSchema: .object(
            properties: [
                "title": .string(description: "Reminder title."),
                "notes": .string(description: "Optional notes."),
                "dueDate": .string(description: "Optional ISO 8601 due date/time."),
                "listName": .string(description: "Optional reminder list name.")
            ],
            required: ["title"]
        )
    ) { input async throws in
        guard let title = input["title"]?.stringValue else {
            return .object(["success": false, "error": "Title is required."])
        }

        let store = EKEventStore()
        try await store.requestFullAccessToReminders()

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = input["notes"]?.stringValue

        if let dueDateString = input["dueDate"]?.stringValue,
           let dueDate = ISO8601DateFormatter().date(from: dueDateString) {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }

        if let listName = input["listName"]?.stringValue {
            reminder.calendar = store.calendars(for: .reminder).first { $0.title == listName }
        }
        reminder.calendar = reminder.calendar ?? store.defaultCalendarForNewReminders()

        try store.save(reminder, commit: true)
        return .object(["success": true, "reminderId": .string(reminder.calendarItemIdentifier)])
    }
}
