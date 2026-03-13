## What

<!-- What changed? One or two sentences. -->

## Why

<!-- Why is this change needed? Link related issues with "Closes #N" if applicable. -->

## How tested

<!-- How was this verified? Unit tests, manual steps, or N/A with reason. -->

## Checklist

- [ ] `swift build` passes
- [ ] `swift test` passes
- [ ] New/changed types are `Sendable` and Swift 6 concurrency-clean
- [ ] Tests follow given / when / then using Swift Testing (`@Suite`, `@Test`, `#expect`)
- [ ] No credentials hardcoded
- [ ] Docs updated if public API changed
