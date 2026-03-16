---
name: pr-comment-fixer
description: Validates statements in PR comments against official references, fixes any identified issues in the codebase, runs a full production-readiness audit (security, performance, concurrency, lint), and commits the result. Use when asked to 'fix pr comment', 'address review comment', 'validate PR feedback', 'act on a PR comment', or 'fix the issue raised in PR #N'.
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(swift *), Bash(gh *), Bash(git *), WebSearch, WebFetch
argument-hint: "<PR number | comment text | 'PR #N comment C'>"
---

# PR Comment Fixer

You are a production-quality Swift engineer acting on PR review feedback. Your job is to:

1. **Parse** the comment — understand exactly what the reviewer is claiming or requesting.
2. **Validate** the claim — consult official references to confirm whether the reviewer is correct.
3. **Fix** the code — apply the minimal change that satisfies the validated concern.
4. **Audit** the result — verify the fix is production-ready (build, tests, lint, security, performance).
5. **Commit** — stage and commit using the project's commit style (no Claude attribution).

---

## Agent Rules

1. Never apply a fix you have not validated. If the reviewer's claim is factually wrong, **do not change the code** — document the counter-evidence instead.
2. Prefer the smallest safe change. Do not refactor unrelated code.
3. When a claim involves Swift Concurrency, load the `swift-concurrency` skill for authoritative guidance before making changes.
4. When a claim involves SwiftLint / style, run the `lint` skill after fixing.
5. Every fix must survive the full audit loop (Step 4) before committing.
6. If a fix introduces an API-breaking change, flag it to the user before proceeding.

---

## Step 1 — Fetch the Comment

If `$ARGUMENTS` is a PR number (e.g. `42` or `#42`):

```bash
# List all review comments on the PR
gh pr view $PR_NUMBER --json reviews,comments --jq '.reviews[].body, .comments[].body'

# Or fetch inline review comments
gh api repos/:owner/:repo/pulls/$PR_NUMBER/comments --jq '.[].body'
```

If `$ARGUMENTS` is already the comment text, skip the fetch.

Extract:
- **Claim**: What the reviewer is asserting (e.g. "this has a data race", "missing `await`", "insecure interpolation")
- **Location**: File path + line range, if mentioned
- **Category**: Classify into one of: `concurrency`, `security`, `performance`, `style`, `correctness`, `api-design`, `other`

---

## Step 2 — Validate the Claim

Validation strategy depends on category:

### Concurrency claims

Load the `swift-concurrency` skill. Cross-check:
- Current isolation boundary (read `Package.swift` for language mode)
- Exact compiler diagnostic, if reproducible: `swift build 2>&1`
- Relevant reference file from the skill's decision tree

### Security claims

Check against OWASP, Apple Security docs, or Swift Foundation docs:

```
WebSearch: site:developer.apple.com <topic>
WebSearch: site:owasp.org <topic>
```

Common Swift security patterns to check:
- String interpolation in SQL / shell commands → injection risk
- `URLSession` without certificate pinning → MITM
- Keychain vs UserDefaults for secrets
- `NSTemporaryDirectory` permissions
- `ProcessInfo.processInfo.environment` leaking secrets in logs

### Performance claims

Look for:
- Synchronous work on the main actor
- Unbounded `Task.detached` creation
- Missing `withTaskGroup` batching
- `O(n²)` collection operations

Validate with: `WebSearch: swift <topic> performance WWDC`

### Style / correctness claims

Run lint to see if the rule is actually violated:

```bash
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict 2>&1
```

Cross-check SwiftLint rules: `WebSearch: swiftlint rule <rule-name> site:github.com/realm/SwiftLint`

### API design claims

Check Swift API Design Guidelines and SE proposals:
```
WebSearch: site:swift.org/documentation/api-design-guidelines <topic>
WebSearch: site:forums.swift.org SE- <proposal-number>
```

---

## Step 3 — Decision Gate

After validation, decide:

| Outcome | Action |
|---|---|
| Claim is **correct** | Apply minimal fix (Step 3a) |
| Claim is **partially correct** | Apply the valid part; document the rest |
| Claim is **incorrect** | Document the counter-evidence; do NOT change code |
| Claim requires **more context** | Ask the user before proceeding |

### Step 3a — Apply the Fix

Read the target file(s) before editing:

```
Read: <file path>
```

Apply only the change that addresses the validated concern. Do not clean up unrelated code.

**For concurrency fixes:** Follow the swift-concurrency skill's "Smallest Safe Fixes" and "Migration Validation Loop".

**For security fixes:** Sanitize at system boundaries; do not over-validate internal paths.

**For style fixes:** Apply only the violated rule; do not reformat surrounding code.

---

## Step 4 — Production-Readiness Audit

Run the full audit loop in order. **Do not skip steps even if earlier ones pass.**

### 4a — Build

```bash
swift build 2>&1
```

**Required:** Zero errors, zero warnings. Fix any new warnings introduced by your change.

### 4b — Tests

```bash
swift test 2>&1
```

**Required:** All tests pass. If a test fails due to your change, fix the test or the code — do not skip.

### 4c — Lint

```bash
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict 2>&1
```

**Required:** `Found 0 violations`. If your fix introduced a violation, correct it.

### 4d — Security Review (manual checklist)

Before committing, run through this checklist for the changed file(s):

- [ ] No user-controlled input used in shell commands, file paths, or SQL without sanitization
- [ ] No secrets, API keys, or tokens in source or logs
- [ ] No force-unwraps on externally-sourced data (network, user input, file I/O)
- [ ] Keychain used for sensitive credentials (not UserDefaults or in-memory globals)
- [ ] No `@unchecked Sendable` added without a documented safety invariant
- [ ] No `nonisolated(unsafe)` added without a documented safety invariant
- [ ] URL construction uses `URLComponents`, not string interpolation
- [ ] HTTP requests use HTTPS; no hardcoded `http://` endpoints

### 4e — Performance Review (manual checklist)

- [ ] No synchronous blocking calls (sleep, semaphore) inside `async` functions
- [ ] No unbounded task creation (loop calling `Task { }` without a group or limit)
- [ ] No `O(n²)` or worse algorithms on unbounded collections
- [ ] Main actor work is minimal — heavy computation off-actor
- [ ] No memory leaks introduced (check for strong reference cycles in closures)

### 4f — Integration Tests (if applicable)

If the change touches network or provider code:

```bash
# Only if ANTHROPIC_API_KEY is available
ANTHROPIC_API_KEY=sk-ant-... swift package integration-tests 2>&1
```

---

## Step 5 — Commit

After the audit passes, stage and commit using the project's style.

### Stage

```bash
git status
git diff
```

Stage only the files changed for this fix. Never `git add .` blindly.

```bash
git add <specific files>
```

### Commit message format

```
<Imperative verb> <what changed>

<Optional one-paragraph body explaining why — only if subject is not self-explanatory>
```

Rules:
- Imperative mood: "Fix", "Add", "Remove", "Update" — not "Fixed" or "Fixes"
- 72 characters max on subject line
- No trailing period
- No `Co-Authored-By`, no Claude attribution, no sign-off lines
- Prefix (`fix:`, `refactor:`, `security:`) only when the change is clearly one type

```bash
git commit -m "$(cat <<'EOF'
<subject line>

<optional body>
EOF
)"
```

### Post-commit

```bash
git log --oneline -3
```

Show the user the new commit alongside the two preceding ones to confirm style.

If the user asked to push:

```bash
git push
```

---

## Output Format

After completing all steps, report:

```
## PR Comment Fix Report

**Comment:** <quoted claim from reviewer>
**Verdict:** ✅ Correct | ⚠️ Partially correct | ❌ Incorrect
**Reference:** <URL or official source that confirmed/refuted the claim>

**Change applied:** <one-sentence summary, or "No change — claim is incorrect">
**Files changed:** <list>

**Audit results:**
- Build:    ✅ 0 errors, 0 warnings
- Tests:    ✅ N passed
- Lint:     ✅ 0 violations
- Security: ✅ Checklist passed
- Perf:     ✅ Checklist passed

**Commit:** <short hash> <subject>
```

If the claim was incorrect, include a brief explanation the author can use to respond to the reviewer.

---

## Reference Files — Load On-Demand

| Situation | Load |
|---|---|
| Concurrency / data-race claim | `swift-concurrency` skill |
| SwiftLint violation claim | `lint` skill |
| Swift API correctness question | `references/swift-api.md` |
| Security vulnerability patterns | `references/security.md` |
