@testable import AIProviderKit
@testable import AIProviderKitPersistence
import Foundation
import SwiftData
import Testing

@Suite("SwiftDataConversationStore — Import/Export")
struct ImportExportTests {

    // MARK: - Helpers

    private func makeStore() throws -> SwiftDataConversationStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ConversationRecord.self,
            ConversationTurnRecord.self,
            configurations: config
        )
        return SwiftDataConversationStore(modelContainer: container)
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(conversationFileExtension)
    }

    // MARK: - Export

    @Test("exportConversation produces valid JSON decodable as Conversation")
    func exportConversation_producesValidJSON() async throws {
        // Given
        let store = try makeStore()
        var conv = try await store.createConversation(title: "Export", model: "m")
        conv.turns.append(ConversationTurn(message: .user(text: "Hello")))
        try await store.save(conv)

        // When
        let data = try await store.exportConversation(conv.id)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Conversation.self, from: data)

        // Then
        #expect(decoded.id == conv.id)
        #expect(decoded.title == "Export")
        #expect(decoded.turns.count == 1)
    }

    @Test("exportConversation throws for unknown ID")
    func exportConversation_throwsForUnknown() async throws {
        // Given
        let store = try makeStore()

        // When / Then
        await #expect(throws: AIError.self) {
            try await store.exportConversation(UUID())
        }
    }

    @Test("exportConversation writes .chat file to disk")
    func exportConversation_writesToDisk() async throws {
        // Given
        let store = try makeStore()
        let conv = try await store.createConversation(title: "File", model: "m")
        let url = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // When
        try await store.exportConversation(conv.id, to: url)

        // Then
        #expect(FileManager.default.fileExists(atPath: url.path()))
    }

    // MARK: - Import

    @Test("importConversation round-trips with exportConversation")
    func importExport_roundTrip() async throws {
        // Given — export from one store
        let sourceStore = try makeStore()
        var conv = try await sourceStore.createConversation(title: "Round-trip", model: "m")
        conv.turns.append(ConversationTurn(message: .user(text: "Hi")))
        try await sourceStore.save(conv)
        let data = try await sourceStore.exportConversation(conv.id)

        // When — import into a fresh store
        let targetStore = try makeStore()
        let imported = try await targetStore.importConversation(from: data)

        // Then
        #expect(imported.id == conv.id)
        #expect(imported.title == "Round-trip")
        #expect(imported.turns.count == 1)

        let fetched = try await targetStore.conversation(byId: conv.id)
        #expect(fetched != nil)
    }

    @Test("importConversation from .chat file URL")
    func importConversation_fromFileURL() async throws {
        // Given — export to a .chat file
        let sourceStore = try makeStore()
        let conv = try await sourceStore.createConversation(title: "File import", model: "m")
        let url = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try await sourceStore.exportConversation(conv.id, to: url)

        // When — import from the file
        let targetStore = try makeStore()
        let imported = try await targetStore.importConversation(from: url)

        // Then
        #expect(imported.id == conv.id)
        #expect(imported.title == "File import")
    }

    @Test("importConversation overwrites existing conversation with same ID")
    func importConversation_overwritesExisting() async throws {
        // Given
        let store = try makeStore()
        var conv = try await store.createConversation(title: "Original", model: "m")
        conv.title = "Updated via import"
        conv.turns.append(ConversationTurn(message: .user(text: "New turn")))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(conv)

        // When
        let imported = try await store.importConversation(from: data)

        // Then
        #expect(imported.title == "Updated via import")
        let fetched = try await store.conversation(byId: conv.id)
        #expect(fetched?.turns.count == 1)
    }

    @Test("importConversation throws decodingFailed for malformed data")
    func importConversation_throwsForMalformedData() async throws {
        // Given
        let store = try makeStore()
        let badData = Data("not json".utf8)

        // When / Then
        await #expect(throws: AIError.self) {
            try await store.importConversation(from: badData)
        }
    }

    // MARK: - Bulk export / import

    @Test("exportAll and importConversations round-trip multiple conversations")
    func bulkExportImport_roundTrip() async throws {
        // Given
        let sourceStore = try makeStore()
        let conv1 = try await sourceStore.createConversation(title: "One", model: "m")
        let conv2 = try await sourceStore.createConversation(title: "Two", model: "m")
        let data = try await sourceStore.exportAll()

        // When
        let targetStore = try makeStore()
        let imported = try await targetStore.importConversations(from: data)

        // Then
        #expect(imported.count == 2)
        let all = try await targetStore.allConversations()
        #expect(all.count == 2)
        let ids = Set(all.map(\.id))
        #expect(ids.contains(conv1.id))
        #expect(ids.contains(conv2.id))
    }
}
