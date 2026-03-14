---
name: commit
description: Stage and commit changes with a well-crafted message matching this project's style. Use when asked to 'commit', 'commit my changes', 'create a commit', 'write a commit message', or 'commit and push'.
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read
argument-hint: "[optional hint about what changed]"
---

You are a commit author for this Swift Package project. Your job is to inspect staged (and unstaged) changes, craft a commit message that matches the project's style exactly, and create the commit.

## Commit style

```
<subject line>

<optional body>
```

**Subject line rules:**
- Imperative mood: "Add", "Fix", "Remove", "Update", "Refactor" — not "Added" or "Adds"
- 72 characters max
- No trailing period
- `type: ` prefix is optional and used loosely — only add it when the change is clearly one type (e.g., `fix:`, `docs:`, `chore:`, `feat:`, `refactor:`, `test:`, `ci:`)
- When in doubt, skip the prefix and write a plain imperative subject

**Body rules (only include when the subject alone is not self-explanatory):**
- Single short paragraph — no bullets, no lists
- Explains *why*, not *what* (the diff shows what)
- Blank line between subject and body

**Never include:**
- `Co-Authored-By` trailers
- Claude attribution of any kind
- Sign-off lines

## Real examples from this project

```
Fix cancellation misreporting, tvOS location guard, and roadmap state
Replace Mint with SimplyDanny/SwiftLintPlugins SPM binary plugin
Add Apple Intelligence integration suite alongside Claude
Opt into Node.js 24 for GitHub Actions runners
Fix all SwiftLint violations across sources and tests
docs: overhaul README and promote Apple Intelligence in banner
chore: remove .gitkeep from AppleIntelligenceProviderTests
feat: add AppleIntelligenceProvider with native FoundationModels integration
```

## Steps

### 1 — Assess state

```bash
git status
git diff --staged
git diff
```

If nothing is staged, check whether unstaged changes should be staged. If `$ARGUMENTS` gives a hint about intent, use it to decide which files to stage. Ask before staging files that look unrelated to the described change.

### 2 — Stage (if needed)

Prefer staging specific files by name. Never `git add .` blindly — check `git status` first and exclude:
- `.env` files or any file containing secrets
- Large binaries unrelated to the change
- Unintended scratch files

### 3 — Inspect the diff

Read `git diff --staged` in full. For each changed file, identify:
- What changed (added, removed, modified)
- Why it changed (feature, bug fix, cleanup, dependency update, CI, docs)

Cross-reference with `$ARGUMENTS` if provided.

### 4 — Draft the message

Apply the style rules above. Choose the shortest accurate subject. Add a body only if the subject leaves important context unstated.

### 5 — Commit

```bash
git commit -m "$(cat <<'EOF'
<subject>

<optional body>
EOF
)"
```

Use the heredoc form to avoid shell escaping issues with apostrophes or special characters.

### 6 — Confirm

Run `git log --oneline -3` and show the user the new commit alongside the two preceding ones so they can verify the message fits the project style.

## Safety rules

- Never amend a commit that has already been pushed
- Never force-push to `main` or `master`
- Never skip hooks (`--no-verify`) — if a hook fails, diagnose and fix it
- Do not push unless the user explicitly asks
