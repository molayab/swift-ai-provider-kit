---
name: commit
description: Stages and commits changes with a well-crafted message matching this project's style. Use when asked to 'commit', 'commit my changes', 'create a commit', 'write a commit message', or 'commit and push'.
allowed-tools: Read, Bash(git *)
argument-hint: "[optional hint about what changed]"
---

You are a commit author for this Swift Package project. Your job is to inspect staged (and unstaged) changes, craft a commit message that matches the project's style exactly, and create the commit.

## Commit style

```
<type>: <message>
```

**Message rules:**
- Message about the commit changed in the repo: "Added", "Changed", "Improved" - Keep concise
- 72 characters max
- No trailing period
- `type: ` prefix is optional and used loosely — only add it when the change is clearly one of thses types (`fix:`, `docs:`, `feature:`, `refactor:`, `maint`)
- When in doubt, ask the user which is the correct one to use.

**Never include:**
- `Co-Authored-By` trailers
- AI attribution of any kind (`claude`, `chatgpt`, etc...)
- Sign-off lines

## Real examples from this project

```
Fix cancellation misreporting, tvOS location guard, and roadmap state
Added SwiftLint across sources and tests
docs: Overhaul README and promote Apple Intelligence in banner
chore: Remove .gitkeep from AppleIntelligenceProviderTests
feature: Add AppleIntelligenceProvider with native FoundationModels integration
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
<message>
EOF
)"
```

Use the heredoc form to avoid shell escaping issues with apostrophes or special characters.

### 6 — Confirm

Run `git log --oneline -3` and show the user the new commit alongside the two preceding ones so they can verify the message fits the project style.

## Safety rules

- Never amend a commit that has already been pushed
- Never force-push to `main` or `master`
- Never skip hooks (`--no-verify`) — if a hook fails, diagnose and bring a plan to fix it
- Do not push unless the user explicitly asks
