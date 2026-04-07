# Agent Memory Protocol

Per-agent memory with three freshness tiers — short-term (inline), medium-term (referenced), archival (timestamped).

## Motivation

Each IExClaw agent needs persistent memory across sessions. The workspace root already uses `MEMORY.md` + `memory/` — this protocol recurses that pattern down to every agent. A flat memory dump wastes tokens; a pure archive is too slow to access. Three tiers balance *immediacy* against *cost*:

- **Short-term:** agent sees it every wake (high token cost, high relevance)
- **Medium-term:** agent knows it exists, loads on demand (low token cost, moderate relevance)
- **Archival:** agent must search to find it (zero token cost, discoverable)

This is a fractal of the workspace root `SOUL.md` + `MEMORY.md` pattern, one level down.

**Cross-reference:** workspace root `MEMORY.md` and `SOUL.md` (the parent fractal). Task spec: `tasks/draft-agent-memory-protocol-three-tier-memory.md`.

## Directory Shape

```
agents/
  trader/
    SOUL.md              # agent identity + behavior
    MEMORY.md            # memory index (inline + referenced entries)
    memories/            # all memory files live here
      20260405T1329_market-opened-bullish.memory.md
      20260404T0912_portfolio-rebalanced.memory.md
      20260401T1600_learned-slippage-pattern.memory.md
  analyst/
    SOUL.md
    MEMORY.md
    memories/
      20260405T1400_earnings-q1-summary.memory.md
      ...
```

Each agent owns its `MEMORY.md` and `memories/`. No cross-agent memory sharing (yet) — that's coordination-layer territory.

## The Three Tiers

### Tier 1: Short-term (Inline)

The full content is embedded directly in `MEMORY.md` as a quoted block.

```markdown
<!-- MEMORY.md -->
## Active Context

### Current Task: Q1 Portfolio Rebalance
<!-- inline from memories/20260405T1329_market-opened-bullish.memory.md -->
> Bullish open on AAPL, GOOG. Target allocation: 60/40 growth/value.
> Slippage model updated per lesson from 20260401. Stop-loss at -2%.
> <!-- end inline -->
```

**When to use:**
- Active task context the agent needs every wake
- Recent decisions that shape current behavior
- Fresh learnings not yet internalized into patterns

**Cost:** tokens in every prompt. Keep it lean — if MEMORY.md exceeds ~80 lines of inline content, it's time to demote.

### Tier 2: Medium-term (Referenced)

Listed by path with a one-line summary. Requires an explicit `read_file` to load.

```markdown
<!-- MEMORY.md -->
## Referenced Memories

- `memories/20260404T0912_portfolio-rebalanced.memory.md` — Q1 rebalance: moved 20% from bonds to tech
- `memories/20260401T1600_learned-slippage-pattern.memory.md` — Slippage spikes on low-volume altcoins; use limit orders
```

**When to use:**
- Project history that may become relevant again
- Past decisions with ongoing consequences
- Learned patterns that apply to future but not every session

**Cost:** ~1 line per entry in MEMORY.md. Content only loaded when needed.

### Tier 3: Archival (Timestamped)

Lives in `memories/` with **no index entry** in `MEMORY.md`. Agent must search (`grep`, `find`, or future Memory NPC) to discover it.

```markdown
<!-- memories/20260315T1030_weekly-market-review.memory.md -->
# Weekly Market Review — 2026-03-15

S&P up 2.1%. Crypto mixed. No actionable signals this week.
```

**When to use:**
- Raw logs, one-time events, weekly reviews
- Background material ("that one time at band camp")
- Anything worth keeping but not worth promoting

**Cost:** zero tokens until searched. Fully discoverable via filesystem tools.

## Naming Convention

All memory files follow this pattern:

```
memories/YYYYMMDDTHHMM_kebab-slug.memory.md
```

Components:
- **Timestamp:** ISO 8601 compact, local time (note TZ in file header if ambiguous)
- **Separator:** single underscore
- **Slug:** 3–6 words, kebab-case, descriptive
- **Suffix:** `.memory.md` — disambiguates from task docs and other markdown

Examples:

```
memories/20260405T1329_market-opened-bullish.memory.md
memories/20260404T0912_portfolio-rebalanced.memory.md
memories/20260401T1600_learned-slippage-pattern.memory.md
memories/20260328T1100_researched-etf-fees.memory.md
memories/20260315T1030_weekly-market-review.memory.md
memories/20260310T0845_debugged-order-routing.memory.md
```

## Promotion / Demotion Lifecycle

Memories flow between tiers based on relevance and age.

```
New memory → [short-term: inline] → [medium-term: referenced] → [archival: unindexed]
                  ↑                                          |
                  └──────────── promote if relevant ──────────┘
```

### Lifecycle rules

1. **Creation** — New memory starts as short-term (inline in MEMORY.md).
2. **Demotion to referenced** — Triggered by either:
   - Age: memory is N+ days old (N varies by agent, default 3–5)
   - Bloat: MEMORY.md inline section exceeds ~80 lines
   - Action: pull content out into `memories/`, replace inline block with a referenced entry (path + 1-line summary)
3. **Demotion to archival** — Triggered by:
   - Age: referenced memory not loaded in M+ sessions (M varies, default 7–10)
   - Action: remove the referenced entry from MEMORY.md. File stays in `memories/`.
4. **Promotion** — Any memory can be promoted back up:
   - A task references it → promote to referenced (add path to MEMORY.md)
   - A task depends on it every wake → promote to short-term (inline the content)

### Who does the moving?

Currently: the agent itself, during its wake-up routine or when MEMORY.md gets long.

Future: a **Memory NPC** (see below) can automate demotion based on access frequency and age heuristics.

## Storage Discipline

### DIRT: Data Is Real, There

- **Filesystem-first.** All memories are markdown files. No database, no SQLite, no key-value store.
- **Human-readable.** Any memory file can be `cat`'d and understood without tooling.
- **Append-heavy.** We add memory files far more often than we edit them.
- **Deletion is rare.** Prefer demotion to archival. Only delete if the memory is factually wrong or actively harmful.

### Editing vs creating

- **New memories:** `write` to create a new `.memory.md` file
- **Updating MEMORY.md index:** `edit` to add/remove inline blocks and referenced entries
- **Editing existing memories:** rare, but allowed. Use `edit`, never `write` (avoids overwriting)

### Filesize guardrails

- Single memory file: aim under 100 lines. Split if longer.
- `MEMORY.md` total: aim under 200 lines. Demote aggressively to stay lean.
- `memories/` directory: no hard limit, but consider periodic archival pruning (move old files to `memories/archive/`).

## Memory NPC (Future)

A dedicated librarian agent that helps other agents **find** relevant memories.

**Responsibilities:**
- Read the `memories/` corpus on request
- Return pointers (paths) with summaries
- Suggest memories relevant to a current task
- Automate demotion based on access frequency

**Boundaries:**
- Does NOT decide what to remember — that's always the owning agent's call
- Does NOT edit another agent's MEMORY.md — only suggests changes
- Does NOT delete memories — only suggests archival

This is a coordination-layer concern, not implemented yet. See `ROADMAP.mmd` for timeline.

## Open Questions / TODOs

- [ ] What's the right default for N (short → medium) and M (medium → archival) per agent type?
- [ ] Should cross-agent memory sharing go through a shared `memories/` or through the Memory NPC?
- [ ] How does MEMORY.md interact with the roundtable protocol (see `roundtable/`)?
- [ ] Timestamp timezone: always UTC in filenames, or allow local with header annotation?
- [ ] Should there be a max `memories/` file count before auto-archival kicks in?
- [ ] Embedding-based search vs grep — when does the complexity become worth it?
- [ ] Implement a Memory NPC prototype for the librarian role
