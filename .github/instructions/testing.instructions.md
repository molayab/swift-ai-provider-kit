---
applyTo: "Tests/**/*.swift"
---

# Testing Rules

## Framework

- Use Swift Testing exclusively: `import Testing`, `@Suite`, `@Test`, `#expect`, `#require`.
- Flag any use of `XCTest`, `XCTestCase`, or `XCTAssert*`.

## Structure

- Every test follows given / when / then with inline comments:

```swift
@Test func someFeature() async throws {
    // Given
    let provider = MockAIProvider(response: .fixture)
    let client = AIClient(provider: provider)

    // When
    let response = try await client.send(.fixture)

    // Then
    #expect(response.stopReason == .endTurn)
}
```

## Mocks

- Mocks live in `Tests/<Target>/Mocks/`. No inline anonymous stubs.
- `MockAIProvider` -- configurable stub that records received requests.
- `SequentialMockProvider` -- returns a queue of responses; use for multi-turn tool-use tests.
- `MockHTTPClient` -- stubs the HTTP layer for `ClaudeProvider` tests. Never hit a real network endpoint.

## Scope

- Unit tests must not require environment variables or network access.
- Flag any test that calls a real API endpoint.

## Naming

- Test method names describe the scenario and expected outcome: `send_forwardsRequestToProvider`, `stream_throwsWhenProviderUnsupported`.
- Suite names match the type under test: `@Suite("AIClient")`.
