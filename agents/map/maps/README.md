# maps/ — Cartographer's Notebook

Saved results from MAP queries. Each map answers one question. Read before asking MAP to walk the same ground twice.

## Naming
`<slug>.md` — lowercase, hyphens, describes the question.

Examples:
- `project-structure.md` — "what lives in projects/iex-claw/?"
- `vendors-with-edit-formats.md` — "which vendors have edit format code?"
- `elixir-vendor-entry-points.md` — "where do symphony and jido start?"

## Map Template
```markdown
# <Question this map answers>

**Generated:** YYYY-MM-DD HH:MM
**Asked by:** <agent name>
**Query:** `<command or function call>`

## Result
<tree, list, or content>

## Interpretation
<1-3 sentence note on what this tells us>

## Suggested Follow-ups
- <next question worth asking>
```

## Lifecycle
Maps age. When the territory changes, maps become stale. MAP re-runs on demand; old maps can be archived to `maps/archive/` when stale.
