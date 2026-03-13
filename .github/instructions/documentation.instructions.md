---
applyTo: "Documentation/**/*.md"
---

# Documentation Rules

## Diagrams

- All diagrams must use Mermaid syntax (`graph`, `sequenceDiagram`, `flowchart`).
- Flag ASCII art diagrams -- replace them with Mermaid equivalents.
- Supported diagram types: `graph` for dependency and module graphs, `sequenceDiagram` for request/response flows, `flowchart` for decision flows.

## Architecture Changes

- Public type additions or removals require an update to `Documentation/Architecture.md`.
- New use case flows require an update to `Documentation/UseCases.md`.
- New provider implementations require an update to `Documentation/AddingAProvider.md`.

## ROADMAP Format

- Each milestone entry uses a short intro paragraph (optional) and a flat `- [ ]` bullet checklist.
- No sub-headers, code blocks, or diagrams inside `ROADMAP.md`.
- Issue files with detailed design live in `Documentation/Issues/<slug>.md`; `ROADMAP.md` links to them with a one-sentence intro only.
