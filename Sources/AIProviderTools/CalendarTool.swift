import AIProviderKit
import EventKit

/// Ready-to-use `Tool`s for reading and writing calendar events via EventKit.
///
/// ```swift
/// await client.toolRegistry.registerAll(CalendarTool.self)
/// ```
public enum CalendarTool: ToolGroup {

    /// All provided calendar tools.
    public static var all: [Tool] { [listEvents, createEvent] }

    // MARK: - List Events

    public static let listEvents = Tool(
        name: "list_calendar_events",
        description: "Lists upcoming calendar events within a date range.",
        inputSchema: .object(
            properties: [
                "daysAhead": .integer(description: "How many days ahead to look. Default: 7."),
                "calendarName": .string(description: "Optional calendar name to filter. Omit for all calendars.")
            ]
        )
    ) { input async throws in
        let daysAhead = input["daysAhead"]?.intValue ?? 7
        let calendarName = input["calendarName"]?.stringValue

        let store = EKEventStore()
        try await store.requestFullAccessToEvents()

        let calendars = store.calendars(for: .event).filter {
            calendarName == nil || $0.title == calendarName
        }

        let start = Date.now
        let end = Calendar.current.date(byAdding: .day, value: daysAhead, to: start) ?? start

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = store.events(matching: predicate)

        let eventList: [JSONValue] = events.map { event in
            .object([
                "title": .string(event.title ?? ""),
                "startDate": .string(ISO8601DateFormatter().string(from: event.startDate)),
                "endDate": .string(ISO8601DateFormatter().string(from: event.endDate)),
                "calendar": .string(event.calendar.title),
                "notes": event.notes.map { .string($0) } ?? .null,
                "isAllDay": .bool(event.isAllDay)
            ])
        }
        return .array(eventList)
    }

    // MARK: - Create Event

    public static let createEvent = Tool(
        name: "create_calendar_event",
        description: "Creates a new calendar event.",
        inputSchema: .object(
            properties: [
                "title": .string(description: "Event title."),
                "startDate": .string(description: "ISO 8601 start date/time."),
                "endDate": .string(description: "ISO 8601 end date/time."),
                "notes": .string(description: "Optional event notes."),
                "calendarName": .string(description: "Optional target calendar name.")
            ],
            required: ["title", "startDate", "endDate"]
        )
    ) { input async throws in
        guard let title = input["title"]?.stringValue,
              let startString = input["startDate"]?.stringValue,
              let endString = input["endDate"]?.stringValue,
              let startDate = ISO8601DateFormatter().date(from: startString),
              let endDate = ISO8601DateFormatter().date(from: endString) else {
            return .object(["success": false, "error": "Invalid or missing required fields."])
        }

        let store = EKEventStore()
        try await store.requestFullAccessToEvents()

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = input["notes"]?.stringValue

        if let calendarName = input["calendarName"]?.stringValue {
            event.calendar = store.calendars(for: .event).first { $0.title == calendarName }
        }
        event.calendar = event.calendar ?? store.defaultCalendarForNewEvents

        try store.save(event, span: .thisEvent)
        return .object(["success": true, "eventId": .string(event.eventIdentifier ?? "")])
    }
}
