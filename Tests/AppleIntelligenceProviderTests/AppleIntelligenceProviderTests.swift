import Testing
import Foundation
import AIProviderKit
@testable import AppleIntelligenceProvider

@Suite("AppleIntelligenceProvider")
struct AppleIntelligenceProviderTests {

    // MARK: - Properties

    private let mockFactory: MockFMSessionFactory
    private let mockSession: MockFMSession
    private let sut: AppleIntelligenceProvider

    init() {
        mockFactory = MockFMSessionFactory()
        mockSession = MockFMSession()
        mockFactory.session = mockSession
        sut = AppleIntelligenceProvider(sessionFactory: mockFactory)
    }

    // MARK: - Helpers

    private func makeRequest(
        systemPrompt: String? = nil,
        tools: [Tool] = []
    ) throws -> AIRequest {
        let builder = AIRequestBuilder()
            .model(.appleIntelligenceDefault)
            .addMessage(.user(text: "Hello"))
        if let systemPrompt {
            builder.systemPrompt(systemPrompt)
        }
        for tool in tools {
            builder.addTool(tool)
        }
        return try builder.build()
    }

    // MARK: - send — Happy Path

    @Test("send returns mapped response from session")
    func send_happyPath_returnsMappedResponse() async throws {
        // Given
        mockSession.stubbedResponse = FMResponse(
            content: "Hello from on-device!",
            toolCalls: [],
            stopReason: .endTurn
        )
        let request = try makeRequest()

        // When
        let response = try await sut.send(request)

        // Then
        #expect(response.text == "Hello from on-device!")
        #expect(response.stopReason == .endTurn)
        #expect(response.model == "com.apple.foundation-models.default")
    }

    @Test("send creates a new session per request")
    func send_createsSessionPerRequest() async throws {
        // Given
        mockSession.stubbedResponse = FMResponse(
            content: "ok",
            toolCalls: [],
            stopReason: .endTurn
        )
        let request = try makeRequest()

        // When
        _ = try await sut.send(request)
        _ = try await sut.send(request)

        // Then
        #expect(mockFactory.makeSessionCallCount == 2)
    }

    @Test("send passes systemPrompt to session factory")
    func send_systemPrompt_passedToFactory() async throws {
        // Given
        mockSession.stubbedResponse = FMResponse(
            content: "ok",
            toolCalls: [],
            stopReason: .endTurn
        )
        let request = try makeRequest(systemPrompt: "Be concise.")

        // When
        _ = try await sut.send(request)

        // Then
        #expect(mockFactory.lastRequest?.systemPrompt == "Be concise.")
    }

    @Test("send passes tools to FMRequest")
    func send_tools_passedToFMRequest() async throws {
        // Given
        mockSession.stubbedResponse = FMResponse(
            content: "ok",
            toolCalls: [],
            stopReason: .endTurn
        )
        let tool = Tool(
            name: "get_weather",
            description: "Gets current weather",
            inputSchema: .object(
                properties: ["city": .string(description: "City name")],
                required: ["city"]
            )
        ) { _ async throws in .null }
        let request = try makeRequest(tools: [tool])

        // When
        _ = try await sut.send(request)

        // Then
        let fmRequest = try #require(mockFactory.lastRequest)
        #expect(fmRequest.tools.count == 1)
        #expect(fmRequest.tools[0].name == "get_weather")
    }

    // MARK: - send — Tool Use Response

    @Test("send maps tool use response to toolUse content blocks")
    func send_toolUseResponse_mapsToToolUseBlocks() async throws {
        // Given
        mockSession.stubbedResponse = FMResponse(
            content: "",
            toolCalls: [
                FMToolCall(
                    id: "call_1",
                    name: "get_weather",
                    argumentsJSON: #"{"city":"Rome"}"#
                )
            ],
            stopReason: .toolUse
        )
        let request = try makeRequest()

        // When
        let response = try await sut.send(request)

        // Then
        #expect(response.stopReason == .toolUse)
        #expect(response.toolUses.count == 1)
        #expect(response.toolUses[0].name == "get_weather")
        #expect(response.toolUses[0].id == "call_1")
        #expect(response.toolUses[0].input == .object(["city": .string("Rome")]))
    }

    // MARK: - send — Error Cases

    @Test("send wraps session errors as inferenceFailed")
    func send_sessionThrows_wrapsAsInferenceFailed() async throws {
        // Given
        let underlying = NSError(domain: "test", code: 42)
        mockSession.stubbedError = underlying
        let request = try makeRequest()

        // When
        var caughtError: AIError?
        do {
            _ = try await sut.send(request)
        } catch {
            caughtError = error
        }

        // Then
        let aiError = try #require(caughtError)
        guard case .inferenceFailed(let wrappedError) = aiError else {
            Issue.record("Expected .inferenceFailed, got \(aiError)")
            return
        }
        #expect((wrappedError as NSError).code == 42)
    }

    // MARK: - stream — Happy Path

    @Test("stream yields text delta events")
    func stream_textDeltas_yieldsTextDeltaEvents() async throws {
        // Given
        mockSession.stubbedStreamDeltas = [
            FMStreamDelta(text: "Hello"),
            FMStreamDelta(text: " world"),
        ]
        let request = try makeRequest()

        // When
        var deltas: [String] = []
        for try await event in sut.stream(request) {
            if case .textDelta(let text) = event {
                deltas.append(text)
            }
        }

        // Then
        #expect(deltas == ["Hello", " world"])
    }

    // MARK: - stream — Error Cases

    @Test("stream propagates stream error")
    func stream_sessionThrows_propagatesError() async throws {
        // Given
        let expectedError = NSError(domain: "test", code: 99)
        mockSession.stubbedError = expectedError
        let request = try makeRequest()

        // When / Then
        var caughtError: (any Error)?
        do {
            for try await _ in sut.stream(request) { }
        } catch {
            caughtError = error
        }
        let nsError = try #require(caughtError as? NSError)
        #expect(nsError.code == 99)
    }

    // MARK: - Static Properties

    @Test("capabilities include text streaming systemPrompt and tools")
    func capabilities_containsExpected() {
        // Given
        let provider = sut

        // When
        let caps = provider.capabilities

        // Then
        #expect(caps.contains(.text))
        #expect(caps.contains(.streaming))
        #expect(caps.contains(.systemPrompt))
        #expect(caps.contains(.tools))
        #expect(!caps.contains(.vision))
    }

    @Test("identifier is apple-intelligence")
    func identifier_returnsExpectedValue() {
        // Given
        let provider = sut

        // When
        let id = provider.identifier

        // Then
        #expect(id == "apple-intelligence")
    }
}
