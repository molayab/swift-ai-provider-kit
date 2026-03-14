---
name: swift-concurrency
description: 'Diagnoses data races, converts callback-based code to async/await, implements actor isolation patterns, resolves Sendable conformance issues, and guides Swift 6/6.2 migration. Use when developers mention: (1) Swift Concurrency, async/await, actors, or tasks, (2) "use Swift Concurrency" or "modern concurrency patterns", (3) migrating to Swift 6 or Swift 6.2, (4) data races or thread safety issues, (5) refactoring closures to async/await, (6) @MainActor, Sendable, or actor isolation, (7) concurrent code architecture or performance optimization, (8) concurrency-related linter warnings, (9) @concurrent, NonisolatedNonsendingByDefault, isolated conformances, or Approachable Concurrency.'
allowed-tools: Read, Grep, Glob, Bash(swift *)
---
# Swift Concurrency

## Agent Rules

1. Analyze `Package.swift` or `.pbxproj` to determine Swift language mode (5.x vs 6) and toolchain before giving advice.
2. Before proposing fixes, identify the isolation boundary: `@MainActor`, custom actor, actor instance isolation, or nonisolated.
3. Do not recommend `@MainActor` as a blanket fix. Justify why main-actor isolation is correct for the code.
4. Prefer structured concurrency (child tasks, task groups) over unstructured tasks. Use `Task.detached` only with a clear reason.
5. If recommending `@preconcurrency`, `@unchecked Sendable`, or `nonisolated(unsafe)`, require:
   - a documented safety invariant
   - a follow-up ticket to remove or migrate it
6. For migration work, optimize for minimal blast radius (small, reviewable changes) and follow the validation loop: **Build → Fix errors → Rebuild → Only proceed when clean**.
7. Load reference files on-demand from the `references/` directory. Read only the specific file relevant to the current diagnostic — do not preload all reference files at once.

## Triage Checklist (Before Advising)

- Capture the exact compiler diagnostics and the offending symbol(s).
- Identify the current isolation boundary and module defaults (`@MainActor`, custom actor, default isolation).
- Confirm whether the code is UI-bound or intended to run off the main actor.

## Quick Fix Mode (Use When)

Use Quick Fix Mode when:
- The errors are localized (single file or one type) and the isolation boundary is clear.
- The fix does not require API redesign or multi-module changes.
- You can explain the fix in 1–2 steps without changing behavior.

Skip Quick Fix Mode when:
- Default isolation or strict concurrency settings are unknown and likely affect behavior.
- The error crosses module boundaries or involves public API changes.
- The fix would require `@unchecked Sendable`, `@preconcurrency`, or `nonisolated(unsafe)` without a clear invariant.

## Project Settings Intake (Evaluate Before Advising)

Concurrency behavior depends on build settings. Before advising, determine these via `Read` on `Package.swift` or `Grep` in `.pbxproj` files:

| Setting | SwiftPM (`Package.swift`) | Xcode (`.pbxproj`) |
|---------|--------------------------|---------------------|
| Default isolation | `.defaultIsolation(MainActor.self)` | `SWIFT_DEFAULT_ACTOR_ISOLATION` |
| Strict concurrency | `.enableExperimentalFeature("StrictConcurrency=targeted")` | `SWIFT_STRICT_CONCURRENCY` |
| Upcoming features | `.enableUpcomingFeature("NonisolatedNonsendingByDefault")` | `SWIFT_UPCOMING_FEATURE_*` |
| Language mode | `// swift-tools-version:` at top | Swift Language Version build setting |

If any of these are unknown, ask the developer to confirm them before giving migration-sensitive guidance.

## Smallest Safe Fixes (Quick Wins)

Prefer edits that preserve behavior while satisfying data-race safety.

- **UI-bound types**: isolate the type or specific members to `@MainActor` (justify why UI-bound).
- **Global/static mutable state**: move into an `actor` or isolate to `@MainActor` if UI-only.
- **Background work**: for work that should always hop off the caller's isolation, mark `@concurrent`; for work that can inherit the caller's isolation (e.g. with `NonisolatedNonsendingByDefault`), use `nonisolated` without `@concurrent`, or use an `actor` to guard mutable state.
- **Sendable errors**: prefer immutable/value types; avoid `@unchecked Sendable` unless you can prove and document thread safety.

## Quick Fix Playbook (Common Diagnostics → Minimal Fix)

- **"Main actor-isolated ... cannot be used from a nonisolated context"**
  - Quick fix: if UI-bound, make the caller `@MainActor` or hop with `await MainActor.run { ... }`.
  - Escalate if this is non-UI code or causes reentrancy → load `references/actors.md`.
- **"Actor-isolated type does not conform to protocol"**
  - Quick fix: add isolated conformance (e.g., `extension Foo: @MainActor SomeProtocol`).
  - Escalate if protocol requirements must be `nonisolated` → load `references/actors.md`.
- **"Sending value of non-Sendable type ... risks causing data races"**
  - Quick fix: confine access inside an actor or convert to a value type with immutable (`let`) state.
  - Escalate before `@unchecked Sendable` → load `references/sendable.md` and `references/threading.md`.
- **SwiftLint `async_without_await`**
  - Quick fix: remove `async` if not required; if required by protocol/override/@concurrent, use narrow suppression with rationale → load `references/linting.md`.
- **"wait(...) is unavailable from asynchronous contexts" (XCTest)**
  - Quick fix: use `await fulfillment(of:)` or Swift Testing equivalents → load `references/testing.md`.

## Escalation Path (When Quick Fixes Aren't Enough)

1. Gather project settings (default isolation, strict concurrency level, upcoming features).
2. Re-evaluate isolation boundaries and which types cross them.
3. Load the relevant reference file from the decision tree below.
4. If behavior changes are possible, document the invariant and add tests/verification steps.

## Reference Files — Load On-Demand

Load only the file that matches the developer's immediate problem. Do not read multiple files speculatively.

| Problem | Load |
|---------|------|
| Starting fresh with async/await, URLSession, or async let | `references/async-await-basics.md` |
| Task lifecycle, cancellation, priorities, task groups | `references/tasks.md` |
| Actor isolation, @MainActor, reentrancy, custom executors, Mutex | `references/actors.md` |
| Sendable conformance, @unchecked Sendable, region isolation, `sending` | `references/sendable.md` |
| Thread/task relationship, suspension points, isolation domains | `references/threading.md` |
| Retain cycles in tasks, weak self patterns | `references/memory-management.md` |
| AsyncSequence, AsyncStream, bridging callbacks | `references/async-sequences.md` |
| AsyncAlgorithms, debounce, merge, Combine migration | `references/async-algorithms.md` |
| Core Data, NSManagedObject, custom executors | `references/core-data.md` |
| Profiling with Instruments, suspension point reduction | `references/performance.md` |
| XCTest async patterns, Swift Testing, flaky test fixes | `references/testing.md` |
| SwiftLint async_without_await, suppression strategies | `references/linting.md` |
| Swift 6 migration strategy, @preconcurrency, FRP migration | `references/migration.md` |
| Swift 6.2 @concurrent, isolated conformances, NonisolatedNonsendingByDefault | `references/swift-6-2.md` |
| Term definitions | `references/glossary.md` |

## Core Patterns — Quick Reference

### Concurrency Tool Selection

| Need | Tool | Key Guidance |
|------|------|-------------|
| Single async operation | `async/await` | Default choice for sequential async work |
| Fixed parallel operations | `async let` | Known count at compile time; auto-cancelled on throw |
| Dynamic parallel operations | `withTaskGroup` | Unknown count; structured — cancels children on scope exit |
| Sync → async bridge | `Task { }` | Inherits actor context; use `Task.detached` only with documented reason |
| Shared mutable state | `actor` | Prefer over locks/queues; keep isolated sections small |
| UI-bound state | `@MainActor` | Only for truly UI-related code; justify isolation |

### Common Scenarios

**Network request with UI update**
```swift
Task { @concurrent in
    let data = try await fetchData()
    await MainActor.run { self.updateUI(with: data) }
}
```

**Processing array items in parallel**
```swift
await withTaskGroup(of: ProcessedItem.self) { group in
    for item in items {
        group.addTask { await process(item) }
    }
    for await result in group {
        results.append(result)
    }
}
```

## Swift 6 / 6.2 — Quick Migration Guide

Key changes in Swift 6:
- **Strict concurrency checking** enabled by default
- **Complete data-race safety** at compile time
- **Sendable requirements** enforced on boundaries
- **Isolation checking** for all async boundaries

Swift 6.2 adds **Approachable Concurrency** — async functions stay on the calling actor by default, `@concurrent` opts into background execution, and isolated conformances let `@MainActor` types conform to non-isolated protocols. Load `references/swift-6-2.md` for patterns and before/after examples.

### Migration Validation Loop

Apply this cycle for each migration change:

1. **Build** — Run `swift build` to surface new diagnostics
2. **Fix** — Address one category of error at a time (e.g., all Sendable issues first)
3. **Rebuild** — Confirm the fix compiles cleanly before moving on
4. **Test** — Run `swift test` to catch regressions
5. **Only proceed** to the next file/module when all diagnostics are resolved

Never batch multiple unrelated fixes — keep commits small and reviewable. For detailed steps, load `references/migration.md`.

## Verification Checklist (After Changing Concurrency Code)

1. Confirm build settings (default isolation, strict concurrency, upcoming features) before interpreting diagnostics.
2. **Build** — Verify the project compiles without new warnings or errors.
3. **Test** — Run tests, especially concurrency-sensitive ones (see `references/testing.md`).
4. **Performance** — If performance-related, verify with Instruments (see `references/performance.md`).
5. **Lifetime** — If lifetime-related, verify deinit/cancellation behavior (see `references/memory-management.md`).
6. Check `Task.isCancelled` in long-running operations.
7. Never use semaphores or locks in async contexts — use actors or `Mutex` instead.
