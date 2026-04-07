---
title: "Adopt YAML frontmatter for all task files"
status: in-progress
tags:
  - infrastructure
  - consistency
  - conroy-requested
  - warm
created: "2026-04-05T15:21:00Z"
updated: "2026-04-05T18:18:00Z"
---

# Adopt YAML frontmatter for all task files

## Description

Conroy-requested. Task files in tasks/ currently use loose markdown fields (Status/Tags/Created as bold lines). Move to YAML frontmatter:
---
status: todo
tags: [...]
created: 2026-04-05
updated: 2026-04-05
---

Why: machine-parseable, consistent across all projects, works with Obsidian/Dendron/static site generators. TodoList NPC should write frontmatter when adding tasks; should parse frontmatter when reading existing ones. Back-migrate existing 24 task files.

## Schema (locked 2026-04-05)

### Required fields

| Field | Type | Notes |
|-------|------|-------|
| `title` | string | Must match the H1 in the body exactly |
| `status` | enum | `todo` \| `in-progress` \| `blocked` \| `done` \| `cancelled` |
| `tags` | list[string] | All values kebab-case |
| `created` | ISO8601 | Date or datetime, UTC |

### Optional fields

| Field | Type | Notes |
|-------|------|-------|
| `updated` | ISO8601 datetime | UTC. Set on status change or meaningful edit |
| `priority` | enum | `hot` \| `warm` \| `cold` |
| `blocked_by` | list[string] | Task slugs (filename without `.md`) |
| `references` | list[string] | Relative paths to files in this repo |
| `lineage` | list[string] | Free-text — where the idea came from |

### Body rules (post-migration)

- **REMOVE** duplicated `**Status:**`, `**Tags:**`, `**Created:**` lines from the body once frontmatter exists
- **KEEP** the H1 title, `## Description`, `## Lineage / References`, and all other body sections
- Preserve all other content verbatim

### Example: before → after

**Before** (`postmaster-npc-auto-wake-agents-on-inbox.md`):

```markdown
# Postmaster NPC — auto-wake agents on inbox

**Status:** todo
**Tags:** agent, infrastructure, npc, bus
**Created:** 2026-04-05 15:21 UTC

## Description

Next evolution of the DIRT bus. Today: Clawd manually wires ...
```

**After:**

```markdown
---
title: Postmaster NPC — auto-wake agents on inbox
status: todo
tags:
  - agent
  - infrastructure
  - npc
  - bus
created: "2026-04-05T15:21:00Z"
---

# Postmaster NPC — auto-wake agents on inbox

## Description

Next evolution of the DIRT bus. Today: Clawd manually wires ...
```

### Migration script spec

**Input:** a `tasks/*.md` file with the legacy header format.

**Parse rules:**
- First `# …` line → `title` (strip `# `)
- `**Status:** X` → `status`
- `**Tags:** a, b, c` → `tags` (split on `, `, trim each)
- `**Created:** YYYY-MM-DD HH:MM UTC` → `created` (normalize to ISO8601 datetime: `YYYY-MM-DDTHH:MM:SSZ`)
- If only a date (no time), produce `YYYY-MM-DDT00:00:00Z`

**Write format:**
```
---
<yaml frontmatter>
---

# Title

<rest of body minus stripped header lines>
```

**Edge cases the script must handle:**
- Files with or without trailing newline
- Tasks missing some optional body sections (no `## Lineage`, etc.)
- Tasks that already have frontmatter → **skip** (log a warning, do not overwrite)
- Comma-separated tags with or without spaces

**Idempotent:** running twice on the same file is safe. Already-migrated files are skipped.
