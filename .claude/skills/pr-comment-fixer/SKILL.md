---
name: pr-comment-fixer
description: Validates statements in PR comments against official references, fixes any identified issues in the codebase, runs a full production-readiness audit (security, performance, concurrency, lint), and commits the result. Use when asked to 'fix pr comment', 'address review comment', 'validate PR feedback', 'act on a PR comment', or 'fix the issue raised in PR #N'.
allowed-tools: Read, Edit, Glob, Grep, Bash(swift *), Bash(gh *), Bash(git *), WebSearch, WebFetch
argument-hint: "<PR number | comment text | 'PR #N comment C'>"
---

# PR Comment Fixer

You are a production-quality Swift engineer acting on PR review feedback. Your job is to:

1. **Parse** the comment — understand exactly what the reviewer is claiming or requesting.
2. **Validate** the claim — consult official references to confirm whether the reviewer is correct.
3. **Confirm** with the user — show your verdict and proposed fix before touching any file.
4. **Fix** the code — apply the minimal change that satisfies the validated concern.
5. **Audit** the result — run the full loop; revise and re-audit if anything fails.
6. **Commit** — delegate to the `commit` skill.

---

## Agent Rules

1. Never apply a fix you have not validated. If the reviewer's claim is factually wrong, **do not change the code** — document the counter-evidence instead.
2. Always show the user your verdict and the exact change you plan to make before editing any file. Wait for confirmation. (Exception: single-line typo or formatting fixes may proceed without confirmation.)
3. Prefer the smallest safe change. Do not refactor unrelated code.
4. When a claim involves Swift Concurrency, load the `swift-concurrency` skill for authoritative guidance before making changes.
5. When a claim involves SwiftLint / style, invoke the `lint` agent after fixing.
6. Every fix must survive the full audit loop (Step 5) before committing. If audit fails, revise the fix and re-audit — do not skip steps.
7. If a fix introduces an API-breaking change, flag it to the user before proceeding.
8. Do not use `Write` to create new source files as part of a fix. `Edit` existing files only. (`Write` is not in the allowed-tools list for this reason.)

---

## When NOT to use this skill

- If the comment is a question or a suggestion with no actionable fix → answer the reviewer directly.
- If the fix requires a significant API redesign or multi-module changes → stop after the verdict and discuss the approach with the user.
- If you are not confident in the validation (no official reference found) → report what you found and ask the user to decide.

---

## Step 1 — Fetch and Parse the Comment

If `$ARGUMENTS` is a PR number (e.g. `42` or `#42`), fetch inline review comments:

```bash
gh pr view $PR_NUMBER --json reviews,comments --jq '.reviews[].body, .comments[].body'
gh api repos/:owner/:repo/pulls/$PR_NUMBER/comments --jq '.[].body'
```

If `gh` returns an authentication error, stop and tell the user: "`gh` is not authenticated — run `gh auth login` first."

If `$ARGUMENTS` is already the comment text, skip the fetch.

Extract:
- **Claim**: What the reviewer is asserting (e.g. "this has a data race", "missing `await`", "insecure interpolation")
- **Location**: File path + line range, if mentioned
- **Category**: One of `concurrency`, `security`, `performance`, `style`, `correctness`, `api-design`, `other`

---

## Step 2 — Validate the Claim

Read the target file and `Package.swift` **in parallel** before running any tool:

```
Read: <target file>   (parallel)
Read: Package.swift   (parallel)
```

If the target file does not exist, stop and report: "File `<path>` not found — the comment may refer to a renamed or deleted file."

After reading, **reason through the claim explicitly** before deciding. Write out:
- What the code actually does
- Whether the reviewer's claim is supported by the code
- Which official source confirms or refutes it

Validation strategy by category:

### Concurrency claims

Load the `swift-concurrency` skill. Cross-check:
- Current isolation boundary and language mode from `Package.swift`
- Exact compiler diagnostic, if reproducible: `swift build 2>&1`
- Relevant reference file from the skill's decision tree

### Security claims

Check against OWASP, Apple Security docs, or Swift Foundation docs:

```
WebSearch: site:developer.apple.com <topic>
WebSearch: site:owasp.org <topic>
```

### Performance claims

```
WebSearch: swift <topic> performance WWDC site:developer.apple.com
```

Look for: synchronous work on the main actor, unbounded `Task.detached` creation, `O(n²)` on unbounded collections.

### Style / correctness claims

Run lint first — confirm the rule is actually violated before changing anything:

```bash
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict 2>&1
```

### API design claims

```
WebSearch: site:swift.org/documentation/api-design-guidelines <topic>
```

Load `references/swift-api.md` for common misunderstandings.

---

## Step 3 — Confirm with the User

Before editing any file, present:

```
**Verdict:** ✅ Correct | ⚠️ Partially correct | ❌ Incorrect
**Reference:** <URL or source>

**Reasoning:** <one short paragraph — what the code does, why the claim is or isn't valid>

**Proposed change:**
File: <path>
- Remove: <what is removed>
+ Add:    <what is added>

Proceed? (yes / no / adjust)
```

- If the claim is **incorrect**: present the counter-evidence the author can use to respond to the reviewer. Stop here unless the user says to proceed anyway.
- If the claim requires **more context**: ask the user for it before proceeding.
- Wait for explicit user approval before moving to Step 4.

---

## Step 4 — Apply the Fix

After user confirmation, apply only the change described in Step 3.

**For concurrency fixes:** Follow the swift-concurrency skill's "Smallest Safe Fixes" and "Migration Validation Loop".

**For security fixes:** Sanitize at system boundaries; do not over-validate internal paths.

**For style fixes:** Apply only the violated rule; do not reformat surrounding code.

---

## Step 5 — Production-Readiness Audit

Run the full audit loop in order. **Do not skip steps even if earlier ones pass.**

After each step, reflect on the output: distinguish errors your change introduced from pre-existing ones. Only fix errors your change caused.

### 5a — Build

```bash
swift build 2>&1
```

**Required:** Zero new errors or warnings. If your change introduced warnings, fix them before continuing.
**If build fails due to your change:** Revise the fix (return to Step 4) and re-run from 5a. Do not proceed to 5b with a broken build.

### 5b — Tests

```bash
swift test 2>&1
```

**Required:** All tests pass.
**If a test fails due to your change:** Fix the test or the code, then re-run from 5a. Do not skip.

### 5c — Lint

```bash
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict 2>&1
```

**Required:** `Found 0 violations`. If your fix introduced a violation, correct it and re-run from 5a.

### 5d — Security Review

For the changed file(s):

- [ ] No user-controlled input in shell commands, file paths, or SQL without sanitization
- [ ] No secrets, API keys, or tokens in source or logs
- [ ] No force-unwraps on externally-sourced data (network, user input, file I/O)
- [ ] Keychain used for sensitive credentials (not `UserDefaults` or in-memory globals)
- [ ] No `@unchecked Sendable` added without a documented safety invariant
- [ ] No `nonisolated(unsafe)` added without a documented safety invariant
- [ ] URL construction uses `URLComponents`, not string interpolation
- [ ] HTTP requests use HTTPS; no hardcoded `http://` endpoints

### 5e — Performance Review

- [ ] No synchronous blocking calls (sleep, semaphore) inside `async` functions
- [ ] No unbounded task creation (loop calling `Task { }` without a group or limit)
- [ ] No `O(n²)` or worse algorithms on unbounded collections
- [ ] Main actor work is minimal — heavy computation off-actor
- [ ] No retain cycles introduced in closures

### 5f — Integration Tests (if applicable)

Only if the change touches network or provider code, and `ANTHROPIC_API_KEY` is available:

```bash
ANTHROPIC_API_KEY=<YOUR_ANTHROPIC_API_KEY> swift package integration-tests 2>&1
```

---

## Step 6 — Commit

Once the full audit passes, show the user the diff and ask for commit confirmation:

```bash
git diff HEAD
```

Then delegate to the `commit` skill — do not re-implement commit logic here:

> Invoke: `/commit`

---

## Output Format

After completing all steps, report:

```
## PR Comment Fix Report

**Comment:** <quoted claim from reviewer>
**Verdict:** ✅ Correct | ⚠️ Partially correct | ❌ Incorrect
**Reference:** <URL or official source>

**Change applied:** <one-sentence summary, or "No change — claim is incorrect">
**Files changed:** <list>

**Audit results:**
- Build:    ✅ 0 new errors/warnings
- Tests:    ✅ N passed
- Lint:     ✅ 0 violations
- Security: ✅ Checklist passed
- Perf:     ✅ Checklist passed

**Commit:** <short hash> <subject>
```

If the claim was incorrect, include a ready-to-paste reply the author can post to the reviewer.

---

## Worked Example

**Input:** `"The shared DateFormatter static property is not thread-safe and will cause data races under Swift 6 strict concurrency."`

**Step 2 — Validate:**
- Read `Sources/AIProviderTools/CurrentTimeTool.swift` and `Package.swift` in parallel.
- `Package.swift` shows `swift-tools-version: 6.2` with `.enableUpcomingFeature("StrictConcurrency")`.
- The static `DateFormatter` is not `Sendable`. Under strict concurrency, accessing it from any isolation domain is flagged.
- Apple docs confirm: `DateFormatter` is not safe for concurrent reads during `string(from:)`.
- `ISO8601DateFormatter` is thread-safe after init per Apple docs — the reviewer is wrong about that part.
- **Verdict:** ⚠️ Partially correct. `DateFormatter` is the real issue; `ISO8601DateFormatter` is not.

**Step 3 — Confirm:**
Present verdict + proposed change (remove both static formatters, use `Date.FormatStyle` / `Date.ISO8601Format()` value types). Wait for user confirmation.

**Step 4 — Fix:**
Replace static formatters with per-call `now.formatted(date: .complete, time: .complete)` and `now.ISO8601Format()`.

**Step 5 — Audit:**
`swift build` → clean. `swift test` → 41 passed. `swift package swiftlint lint --strict` → 0 violations. Checklists passed.

**Step 6 — Commit:**
Delegate to `/commit`.

---

## Reference Files — Load On-Demand

| Situation | Load |
|---|---|
| Concurrency / data-race claim | `swift-concurrency` skill |
| SwiftLint violation claim | `lint` agent |
| Swift API correctness question | `references/swift-api.md` |
| Security vulnerability patterns | `references/security.md` |
