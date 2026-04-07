# Agent Memory Protocol

Three-tier memory for IExClaw agents — session context, indexed recall, and deep archive.

## Motivation

Agents need memory that persists across sessions but doesn't waste every token on stale context. The workspace root already demonstrates the pattern: `MEMORY.md` as a lean index, `memories/` for daily logs, `checkpoints/` for deep snapshots. This protocol formalizes that pattern and extends it to per-agent memory.

The three tiers balance *immediacy* against *cost*:

| Tier | Visibility | Token cost | Consulted when |
|------|-----------|------------|----------------|
| Short-term | Embedded in prompt | High | Every wake |
| Medium-term | Indexed, loaded on demand | Low | When relevant |
| Long-term | Archived, searched on demand | Zero | When needed |

## Existing Patterns (Reference)

The workspace root already uses this model. These are the canonical examples:

### Root `MEMORY.md` — the lean index
```
MEMORY.md              # ~100 lines. Active context, key decisions, open work.
```
Structure: identity → north star → active projects → agents → architecture → decisions → principles → tests → open work → checkpoints. Acts as the *table of contents* for everything else.

### `memories/` — daily logs
```
memories/2026-04-05.md   # Detailed session log: what happened, decisions, commits
```
Format: date-slugged markdown. One file per day. Rich narrative — the "journal."

### `memory/` — daily logs (parallel)
```
memory/2026-04-05.md     # Same pattern, different session's log
```
Currently coexists with `memories/`. Both hold daily session logs. See [Open Questions](#open-questions) about consolidation.

### `checkpoints/` — deep snapshots
```
checkpoints/2026-04-05_20-48_code-self-surgery-and-framework-emerges/
```
Timestamped directories capturing full state at a meaningful moment. Consulted for "what did the codebase look like then?"

## The Three Tiers

### Tier 1: Short-term — Session Context

**What it is:** Information the agent needs *every time it wakes up*. Embedded directly in the prompt via soul docs and the memory index.

**Where it lives:**
- `MEMORY.md` — the "Active Context" and "Key Decisions" sections
- `SOUL.md` — identity and behavioral constants (never changes mid-project)
- Agent prompt injection — whatever the supervisor passes in

**Format:** Plain markdown sections within MEMORY.md. No separate files.

```markdown
<!-- MEMORY.md excerpt -->
## Active Projects (Apr 5)
- **IExClaw** — Elixir agent framework. 4 agents live. 12 open tasks.
- **Reification Labs launch** — PTO Apr 1-14, signups by Apr 15.

## Key Decisions
- **Roundtable 2026-04-05**: Neither Jido nor Ash. Extract to lib/.
```

**When consulted:** Every wake. This is the first thing an agent reads.

**Demotion trigger:** When a decision becomes old news or a project ships. Move it to a referenced entry in MEMORY.md or let it live only in the daily log.

**Size guardrail:** MEMORY.md should stay under ~200 lines total. If the short-term section alone exceeds ~80 lines, demote aggressively.

### Tier 2: Medium-term — MEMORY.md Index + Recent Logs

**What it is:** Recent history that's indexed and loadable, but not in every prompt. The agent *knows it exists* and can `read_file` on demand.

**Where it lives:**
- `MEMORY.md` referenced entries — one-line pointers with summaries
- `memories/YYYY-MM-DD.md` — daily logs from the last ~7 days
- `memory/YYYY-MM-DD.md` — parallel daily logs (see consolidation note)

**Format:**

Index entries in MEMORY.md:
```markdown
## Checkpoints
- `2026-04-05_18-14` — tick protocol + tools molt
- `2026-04-05_20-48` — Code self-surgery + framework emerges
```

Daily log files:
```markdown
<!-- memories/2026-04-05.md -->
# 2026-04-05 — IExClaw Daily Log (Evening Session)

## Session: 6:17 PM – 8:48 PM ET
### Substrate Completion
- Extracted Tools.Messages + Tools.AgentLogger to lib/
...
```

**When consulted:**
- Agent needs to recall what happened in a recent session
- Supervisor asks "what did we do on April 5th?"
- A task references a recent decision or commit

**Naming convention:**
```
memories/YYYY-MM-DD.md
memory/YYYY-MM-DD.md
```
ISO date, hyphenated, `.md` extension. Simple. Human-sortable.

**Demotion trigger:** After ~7–10 days with no access, a daily log becomes long-term. Remove from any active index (it's already not in MEMORY.md — just let it age in the directory).

### Tier 3: Long-term — memories/ Archive

**What it is:** Everything worth keeping but not worth indexing. The deep past. Discoverable but not promoted.

**Where it lives:**
- `memories/` — all daily logs, including old ones
- `checkpoints/` — timestamped full-state snapshots
- Future: `memories/archive/` for very old files

**Format:** Same as medium-term — `YYYY-MM-DD.md` daily logs and `YYYY-MM-DD_HH-MM_slug` checkpoint directories. No index entries. No MEMORY.md references.

**When consulted:**
- Agent needs historical context beyond recent sessions
- Investigating "when did we decide X?"
- Reconstructing project history for documentation

**Discovery method:** `list_dir` on `memories/`, `grep` for keywords, or future Memory NPC search.

**Size guardrail:** No hard limit on file count. Consider moving files older than 30 days to `memories/archive/` if the directory gets unwieldy for `list_dir`.

## Promotion / Demotion Lifecycle

Memories flow between tiers based on relevance and age.

```
New context → [short-term: inline in MEMORY.md]
                    │
                    ▼ age / bloat
            [medium-term: referenced entry or recent log]
                    │
                    ▼ age / disuse
            [long-term: archived, searchable only]
                    │
                    ▼ relevance spike
            [promote back up as needed]
```

### Rules

1. **Creation** — New context starts in short-term (added to MEMORY.md).
2. **Demotion to medium-term** — When:
   - Context is 3–5 days old and no longer shapes every session
   - MEMORY.md exceeds ~200 lines
   - Action: remove from inline sections, optionally add a one-line reference
3. **Demotion to long-term** — When:
   - A daily log hasn't been read in 7–10 sessions
   - Action: nothing — it's already in `memories/` with no index entry
4. **Promotion** — When:
   - A task needs specific historical context → `read_file` from `memories/`
   - A pattern proves repeatedly relevant → add back to MEMORY.md as a referenced entry or inline block

### Who does the moving?

Currently: the agent itself, during wake-up or when MEMORY.md gets long. The `memory_pruner.exs` agent exists for this purpose.

Future: a **Memory NPC** could automate demotion based on access frequency and age heuristics. See [Memory NPC](#memory-npc-future).

## Per-Agent Memory (Future)

The protocol above describes workspace-root memory. The same pattern extends to individual agents:

```
agents/
  code/
    SOUL.md              # identity (already exists)
    MEMORY.md            # agent memory index (not yet created)
    memories/            # agent-specific logs (not yet created)
      2026-04-05.md      # what Code did today
  goal/
    SOUL.md
    MEMORY.md
    memories/
      2026-04-05.md
```

Each agent owns its memory. No cross-agent memory sharing — that's coordination-layer territory (roundtable, message bus).

**Current state:** Agents have SOUL.md, IDENTITY.md, PHILOSOPHY.md. No MEMORY.md or memories/ yet. The workspace root `MEMORY.md` serves as shared context for all agents.

## File Format Reference

### MEMORY.md (index file)
- Plain markdown
- Sections: identity → active context → decisions → open work → checkpoints
- Under 200 lines total
- Edited with `edit_file`, never overwritten

### Daily logs (memories/ and memory/)
- Filename: `YYYY-MM-DD.md`
- Header: `# YYYY-MM-DD — Description`
- Sections: session times, sub-topics, commits, next steps
- One file per day per directory
- Append-heavy; rarely edited after creation

### Checkpoints
- Directory: `checkpoints/YYYY-MM-DD_HH-MM_descriptive-slug/`
- Contains full project state snapshot
- Created at meaningful moments (post-refactor, post-decision)
- Never edited after creation

## Storage Discipline

### DIRT: Data Is Real, There

- **Filesystem-first.** All memory is markdown files. No database.
- **Human-readable.** Any file can be `cat`'d and understood.
- **Append-heavy.** We add far more often than we edit.
- **Deletion is rare.** Prefer demotion. Only delete if factually wrong or harmful.

### Editing rules

| Operation | Tool | When |
|-----------|------|------|
| New daily log | `write_file` | Start of session |
| Update MEMORY.md | `edit_file` | Add/remove context |
| Edit existing log | `edit_file` | Rare corrections only |
| Create checkpoint | filesystem copy | After significant work |

## Memory NPC (Future)

A dedicated librarian agent that helps other agents find relevant memories.

**Responsibilities:**
- Search the `memories/` corpus on request
- Return pointers (paths) with summaries
- Suggest memories relevant to a current task
- Automate demotion based on access frequency

**Boundaries:**
- Does NOT decide what to remember — that's the owning agent's call
- Does NOT edit another agent's MEMORY.md — only suggests changes
- Does NOT delete memories — only suggests archival

## Open Questions

- [ ] Consolidate `memories/` and `memory/` into one directory? Currently both hold daily logs with identical naming.
- [ ] Per-agent MEMORY.md: when should agents get their own? (Currently all share root MEMORY.md)
- [ ] Timestamp timezone: filenames use local date. Should they be UTC?
- [ ] Max `memories/` file count before auto-archival to `memories/archive/`?
- [ ] Embedding-based search vs grep — when does the complexity pay off?
- [ ] Memory NPC implementation timeline — see `ROADMAP.mmd`

## Cross-references

- `MEMORY.md` — workspace root memory index (the canonical example)
- `memories/` — daily session logs
- `memory/` — parallel daily logs
- `checkpoints/` — deep state snapshots
- `agents/memory_pruner.exs` — automated memory maintenance agent
- `agents/code/SOUL.md`, `agents/goal/SOUL.md` — agent identity docs (short-term constants)
- `ROADMAP.mmd` — Memory NPC timeline
