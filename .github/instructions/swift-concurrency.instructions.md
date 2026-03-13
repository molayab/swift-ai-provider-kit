---
applyTo: "Sources/**/*.swift"
---

# Swift 6 Concurrency Rules

## Actors & Isolation

- All mutable shared state must live in an `actor`. Never use `class` + `NSLock` / `DispatchQueue`.
- Actor methods that only read `let` properties may be `nonisolated`; all others must remain isolated.
- `@MainActor` isolation is reserved for SwiftUI-reactive types (`AILogStore`). Do not apply it to business logic.

## Sendable

- Every type that crosses actor or async boundaries must be `Sendable`.
- Value types (`struct`, `enum`) are preferred — they are implicitly `Sendable` when all stored properties are `Sendable`.
- `@unchecked Sendable` requires an inline comment explaining why the conformance is safe.
- Closures stored in `Sendable` types must be `@Sendable`.

## Async / Await

- Use `async/await` throughout. Flag `DispatchQueue`, `OperationQueue`, `GCD`, `NotificationCenter` observers, or completion-handler-based APIs.
- Parallel independent work uses `withThrowingTaskGroup` (or `withTaskGroup`). Never `Task.detached` unless truly fire-and-forget with no result needed.
- `Task { @MainActor in ... }` is acceptable for forwarding log entries from background actors to `AILogStore`.

## final class

- `final class` (non-actor) is acceptable only when all stored properties are `let` and `Sendable` and no mutable state exists after `init`.
- Example: `ClaudeProvider` — injects `Sendable` dependencies, performs no mutation post-init.

## Upcoming Features

- `StrictConcurrency` and `ExistentialAny` are enabled on all targets. `any Protocol` syntax is required for existentials; bare protocol types as values are an error.
