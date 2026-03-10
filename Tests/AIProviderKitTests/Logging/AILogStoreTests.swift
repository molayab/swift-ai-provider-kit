import Testing
@testable import AIProviderKit

@Suite("AILogStore")
struct AILogStoreTests {

    // Justified: AILogStore is annotated @MainActor in its declaration.
    @MainActor
    @Test("append adds entry to entries")
    func append_addsEntry() {
        // Given
        let store = AILogStore()
        let entry = AILogEntry(
            level: .info,
            subsystem: "test",
            category: "unit",
            message: "Hello"
        )

        // When
        store.append(entry)

        // Then
        #expect(store.entries.count == 1)
        #expect(store.entries[0].message == "Hello")
    }

    @MainActor
    @Test("append adds multiple entries in order")
    func append_multipleEntries_addsInOrder() {
        // Given
        let store = AILogStore()
        let entry1 = AILogEntry(level: .info, subsystem: "test", category: "a", message: "First")
        let entry2 = AILogEntry(level: .warning, subsystem: "test", category: "b", message: "Second")

        // When
        store.append(entry1)
        store.append(entry2)

        // Then
        #expect(store.entries.count == 2)
        #expect(store.entries[0].message == "First")
        #expect(store.entries[1].message == "Second")
    }

    @MainActor
    @Test("clear empties all entries")
    func clear_emptiesEntries() {
        // Given
        let store = AILogStore()
        store.append(AILogEntry(level: .info, subsystem: "test", category: "a", message: "One"))
        store.append(AILogEntry(level: .error, subsystem: "test", category: "b", message: "Two"))

        // When
        store.clear()

        // Then
        #expect(store.entries.isEmpty)
    }

    @MainActor
    @Test("maximumEntries evicts oldest when exceeded")
    func maximumEntries_evictsOldest() {
        // Given
        let store = AILogStore()
        store.maximumEntries = 3
        for i in 1...5 {
            store.append(AILogEntry(
                level: .info,
                subsystem: "test",
                category: "unit",
                message: "Entry \(i)"
            ))
        }

        // When (already appended 5 with max 3)
        let entries = store.entries

        // Then
        #expect(entries.count == 3)
        #expect(entries[0].message == "Entry 3")
        #expect(entries[1].message == "Entry 4")
        #expect(entries[2].message == "Entry 5")
    }

    @MainActor
    @Test("maximumEntries of 1 keeps only the latest entry")
    func maximumEntries_one_keepsOnlyLatest() {
        // Given
        let store = AILogStore()
        store.maximumEntries = 1

        // When
        store.append(AILogEntry(level: .info, subsystem: "t", category: "c", message: "A"))
        store.append(AILogEntry(level: .info, subsystem: "t", category: "c", message: "B"))

        // Then
        #expect(store.entries.count == 1)
        #expect(store.entries[0].message == "B")
    }

    @MainActor
    @Test("default maximumEntries is 1000")
    func defaultMaximumEntries_is1000() {
        // Given / When
        let store = AILogStore()

        // Then
        #expect(store.maximumEntries == 1_000)
    }

    @MainActor
    @Test("entries starts empty")
    func entries_startsEmpty() {
        // Given / When
        let store = AILogStore()

        // Then
        #expect(store.entries.isEmpty)
    }
}
