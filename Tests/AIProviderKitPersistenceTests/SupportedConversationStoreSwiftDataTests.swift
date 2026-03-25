@testable import AIProviderKit
@testable import AIProviderKitPersistence
import SwiftData
import Testing

@Suite("SupportedConversationStore+SwiftData")
struct SupportedConversationStoreSwiftDataTests {

    @Test(".swiftData(container:) creates a working store")
    func swiftData_createsWorkingStore() async throws {
        // Given
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ConversationRecord.self,
            ConversationTurnRecord.self,
            configurations: config
        )
        let storeEnum = SupportedConversationStore.swiftData(container: container)

        // When
        let store = storeEnum.makeStore()
        let conv = try await store.createConversation(title: "Test", model: "m")

        // Then
        let fetched = try await store.conversation(byId: conv.id)
        #expect(fetched != nil)
        #expect(fetched?.title == "Test")
    }

    @Test(".custom case returns the provided store instance")
    func custom_returnsProvidedStore() async throws {
        // Given
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ConversationRecord.self,
            ConversationTurnRecord.self,
            configurations: config
        )
        let inner = SwiftDataConversationStore(modelContainer: container)
        let storeEnum = SupportedConversationStore.custom(inner)

        // When
        let store = storeEnum.makeStore()
        let conv = try await store.createConversation(title: "Custom", model: "m")

        // Then
        let fetched = try await store.conversation(byId: conv.id)
        #expect(fetched?.title == "Custom")
    }
}
