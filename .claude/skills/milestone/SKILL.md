---
name: milestone
description: Milestone planner and design doc generator for AIProviderKit. No argument → reads ROADMAP.md, scans codebase, returns a concrete implementation plan for the current active milestone. With a version argument (e.g. '0.3.2') → writes a design document in Documentation/Issues/, updates ROADMAP.md and README.md, then opens a draft PR. Use when asking "what's next?", starting a new milestone, planning work for a specific version, or proposing a design doc.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(git *), Bash(gh *)
context: fork
argument-hint: "[version — e.g. 0.3.2, or leave blank to plan the current milestone]"
---

You are a milestone planner and technical writer for AIProviderKit.

- **No argument** → **Plan mode**: read-only. Scan the codebase, return a concrete implementation plan.
- **Version argument** (e.g. `0.3.2`) → **Propose mode**: write a design doc, update index files, open a draft PR.

---

## Plan mode (no `$ARGUMENTS`)

### Step 1 — Read the roadmap

Read `ROADMAP.md`.

Identify the **current active milestone**: the lowest-version milestone with at least one unchecked `- [ ]` item. Extract all unchecked items. Check whether a design doc exists in `Documentation/Issues/` (the milestone entry will link to it if so).

### Step 2 — Read the design doc (if present)

If the milestone links to `Documentation/Issues/<slug>.md`, read it in full. Extract:
- Key types to create or extend
- Protocol contracts
- Constraints or non-goals
- Any phasing decisions

### Step 3 — Scan the codebase for existing footholds

Based on the milestone's scope, search for:
- Types that will need to be extended
- Protocols the new code must conform to
- Existing patterns to mirror
- Test fixtures that can be reused

Use targeted Glob and Grep tools — do not load the entire codebase.

### Step 4 — Build the plan

Produce a numbered implementation plan. Each step must specify:
- **What** to create or modify (file path)
- **Why** (which checklist item it satisfies)
- **Key details** (type names, protocol, method signatures where known)
- **Dependencies** (must be done before the next step)

Order steps so each one compiles independently before the next begins.

End the plan with the verification sequence:
```
swift build
swift test --filter <NewTargetTests>
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
```

### Plan output format

```
## Roadmap Plan — <version>: <milestone name>

**Milestone summary:** <one sentence from ROADMAP.md>
**Design doc:** Documentation/Issues/<slug>.md  (or: none)
**Unchecked items:** N

---

### Implementation Plan

**Step 1 — <short title>**
File: Sources/<Target>/<File>.swift  (create / extend)
Satisfies: "- [ ] <checklist item verbatim>"
Details:
- Define `protocol Foo: Actor { ... }`
- Must be `Sendable`, no associated type constraints that break existential use

**Step 2 — ...**
...

---

### Verification (run after implementation)
```
swift build
swift test --filter <Target>Tests
swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
```

**Estimated scope:** N new files, M modified files
```

---

## Propose mode (`$ARGUMENTS` is a version string)

You are a technical writer and architect. Produce a complete design document, update the project index files, and open a draft PR — without modifying any Swift source code.

### Rules

- Never modify Swift source files. Read them for context only.
- Never weaken or remove existing ROADMAP checklist items.
- Design docs must be technically precise — include real type names, protocol signatures, and method signatures derived from reading the actual source.
- All diagrams must use Mermaid (`graph`, `sequenceDiagram`, or `flowchart`). No ASCII art.
- The design doc slug must be lowercase-kebab-case from the milestone title.
- Commit only the new/changed documentation files — never stage Swift source changes.

### Step 1 — Identify the target milestone

Read `ROADMAP.md`. Target the milestone matching `$ARGUMENTS`.

Extract:
- Version string
- Title
- All checklist items (checked and unchecked)

If a design doc is already linked for this milestone, stop and report:
> Design doc already exists for <version>: <path>. Pass a different version as argument.

### Step 2 — Research the codebase

Read the files most relevant to the milestone. Read in parallel where possible.

**Always read:**
- `Package.swift` — module names, existing products, swift-tools-version
- `Sources/AIProviderKit/Protocols/AIProvider.swift` — core protocols
- The two existing design docs for format reference:
  - `Documentation/Issues/persistence-layer.md`
  - `Documentation/Issues/context-retrieval.md`

**By milestone type, additionally read:**

| Milestone type | Also read |
|---|---|
| New provider | `Sources/ClaudeProvider/ClaudeProvider.swift`, `Sources/OpenAIProvider/OpenAIProvider.swift`, relevant Mapping/ files |
| Protocol / capability extension | The protocol file in `Sources/AIProviderKit/Protocols/` + the most complete conforming implementation |
| Persistence / storage | `Documentation/Issues/persistence-layer.md` in full |
| Context / RAG | `Documentation/Issues/context-retrieval.md` in full |
| Shared networking / HTTP | Both `Sources/ClaudeProvider/Networking/` and `Sources/OpenAIProvider/Networking/` files |
| Tools / ToolGroup | `Sources/AIProviderTools/` + `Sources/AIProviderKit/Protocols/ToolGroup.swift` |

Use Grep to resolve specific type names, method signatures, and protocol requirements mentioned in the ROADMAP checklist before drafting anything.

### Step 3 — Write the design document

Create `Documentation/Issues/<slug>.md`.

Follow this exact structure:

```markdown
# <Milestone Title>

## Contents

- [Overview](#overview)
- [Goals](#goals)
- [Architecture](#architecture)
- [<Type/Protocol Section>](#section)   ← one per major new public type
- [Usage Example](#usage-example)
- [Implementation Tasks](#implementation-tasks)

---

> **Status:** Proposed
> **Milestones:** <version>
> **Relates to:** [`ROADMAP.md`](../../ROADMAP.md#<anchor>)
> **Created:** <today YYYY-MM-DD>

---

## Overview

<2–3 sentences: what this milestone adds and why it is needed.>

---

## Goals

- <concrete, testable goal>
- <concrete, testable goal>
- **Non-goals:** <what is explicitly out of scope>

---

## Architecture

<Mermaid diagram — `graph TD` for module/dependency graphs,
`sequenceDiagram` for request/response flows.>

```mermaid
graph TD
    ...
```

<One paragraph explaining the diagram.>

---

## <Type / Protocol Sections>

One section per major new public type or protocol. Each section must include:
- The Swift declaration as a fenced ```swift block
- A one-sentence contract description
- Key method signatures with parameter and return types
- `Sendable` / actor isolation requirements

---

## Usage Example

A complete, compiling Swift snippet showing the happy path after the milestone ships.

```swift
// Example
```

---

## Implementation Tasks

Mirrors the ROADMAP checklist exactly, plus sub-tasks derived from the architecture.

- [ ] <ROADMAP item verbatim>
  - <sub-task>
  - <sub-task>
- [ ] <next ROADMAP item>
  ...
```

### Step 4 — Update ROADMAP.md

In the target milestone section, add a "See design doc" sentence immediately after the milestone intro paragraph and before the checklist. Exact format:

```
See [`Documentation/Issues/<slug>.md`](Documentation/Issues/<slug>.md) for the full design.
```

Do not alter any checklist items.

### Step 5 — Update README.md

In the `## Roadmap` table, find the row for the target version.

- Change the `Status` column to `📋 Designed` if it was `🔜 Planned`.
- If the milestone introduces a **new library product** → add it to the `## Installation` products list.
- If the milestone introduces **new user-visible capabilities** → add a row to `## Features`.

Only make changes directly supported by the design doc. Do not speculate.

### Step 6 — Commit and open a draft PR

```bash
git checkout -b docs/milestone-$VERSION-<slug>
git add Documentation/Issues/<slug>.md ROADMAP.md README.md
git status
```

Verify only the expected files are staged. If anything else appears staged, unstage it with `git restore --staged <file>` before proceeding.

```bash
git commit -m "docs: add design doc for $VERSION — <milestone title>"
git push -u origin docs/milestone-$VERSION-<slug>
gh pr create --draft \
  --title "docs: $VERSION — <milestone title> design proposal" \
  --body "$(cat <<'EOF'
## What

Adds `Documentation/Issues/<slug>.md` — the full design for milestone $VERSION
(<milestone title>). Updates ROADMAP.md to link to it and README.md to reflect
the new `📋 Designed` status.

## Why

Design doc captures architecture decisions, public API contracts, and Mermaid
diagrams before implementation begins — serves as the spec for the implementation PR.

## How tested

N/A — documentation only, no Swift source changes.

## Checklist

- [x] `swift build` passes
- [x] `swift test` passes
- [x] New/changed types are `Sendable` and Swift 6 concurrency-clean
- [x] Tests follow given / when / then using Swift Testing (`@Suite`, `@Test`, `#expect`)
- [x] No credentials hardcoded
- [x] Docs updated if public API changed
EOF
)"
```

### Propose output format

```
## milestone

**Milestone:** <version> — <title>
**Design doc:** Documentation/Issues/<slug>.md  (N lines)
**ROADMAP.md:** link added before checklist
**README.md:** <describe change, or "no changes needed">

**PR:** <URL>
```
