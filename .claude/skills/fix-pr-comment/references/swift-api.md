# Swift API Design Reference — PR Comment Fixer

Load this file when a PR comment challenges API naming, protocol design, or Swift idioms.

## Swift API Design Guidelines — Key Rules

Source: https://swift.org/documentation/api-design-guidelines/

### Naming

| Rule | ✅ Good | ❌ Bad |
|---|---|---|
| Clarity at call site | `x.insert(y, at: z)` | `x.insert(y, position: z)` |
| Omit needless words | `allViews.removeElement(cancelButton)` → `allViews.remove(cancelButton)` | keeping redundant type name |
| Name booleans like assertions | `isEmpty`, `isValid` | `empty`, `valid` |
| Protocol names: capabilities use `-able/-ible/-ing` | `Equatable`, `Sendable`, `Streaming` | `EqualProtocol` |
| Protocol names: things use nouns | `Collection`, `Sequence` | `CollectingProtocol` |
| Mutating vs non-mutating pairs | `sort()` / `sorted()` | only one form |

### Parameters

- Label the first parameter when it is not "the direct object": `func move(from start: Index, to end: Index)`
- Omit the label when the first parameter is "the direct object" of a grammatically fluid call: `func insert(_ element: Element, at index: Index)`, called as `x.insert(y, at: z)`
- Default parameter values reduce overloads — prefer one flexible method over many specialized ones
- Variadic parameters vs arrays: use variadic when call-site clarity improves

### Error Handling

- Throw from functions that can fail in a recoverable way
- Return `Optional` only when `nil` has a single obvious meaning
- Do not use `Result` as a function return type when `async throws` is available

### Generics

- Generic type parameters use UpperCamelCase: `Element`, `Index`, `Value`
- Use descriptive names when the role is clear; use `T`, `U` only when truly abstract

## Swift Evolution Proposals — Quick Reference

| Topic | Proposal |
|---|---|
| Structured Concurrency | SE-0304 |
| Actors | SE-0306 |
| `async`/`await` | SE-0296 |
| `Sendable` | SE-0302 |
| `sending` parameter modifier | SE-0430 |
| Isolated conformances | SE-0469 |
| `@concurrent` functions | SE-0461 |
| NonisolatedNonsendingByDefault | SE-0461 |
| `Mutex` in Swift Standard Library | SE-0433 |
| Typed throws | SE-0413 |
| Noncopyable types | SE-0390 |

Find proposals at: https://github.com/swiftlang/swift-evolution/blob/main/proposals/

## Common API Review Misunderstandings

### "This should be a protocol, not a class"

Check: is there a concrete default implementation, or is this truly abstract?
- If every conformer shares behavior → consider `struct` + extension or `class` with inheritance
- If behavior varies by conformer and shared state is needed → `protocol` + default implementations
- Reference: https://developer.apple.com/videos/play/wwdc2015/408/

### "This property should be `let` not `var`"

- If the value never changes after initialization → `let`
- If mutation is required internally but not externally → `private(set) var`
- `let` on `class` types does not prevent mutation of the object, only reassignment

### "Missing `@discardableResult`"

Add `@discardableResult` only when:
- The return value is useful but commonly ignored (e.g., `append` returning the new count)
- The function is called primarily for its side effect

Do NOT add it to suppress a warning on a function whose return value is semantically important.

### "This `async` function doesn't need `async`"

In Swift 6.2 with `NonisolatedNonsendingByDefault`, `async` functions inherit the caller's isolation by default. `async` is still meaningful even without `await` inside if:
- The function signature must match a protocol requirement
- The function calls other `async` functions conditionally
- The function is marked `@concurrent` to opt into background execution

Before removing `async`, check SwiftLint's `async_without_await` rule docs and the `swift-concurrency` skill's linting reference.

## How to Validate an API Design Claim

1. Find the relevant guideline in the Swift API Design Guidelines or SE proposal.
2. Check if the project already has an established pattern for this case (search codebase).
3. If the guideline clearly supports the reviewer → fix it.
4. If the guideline is ambiguous or the reviewer is applying it incorrectly → document the counter-argument with the URL.
