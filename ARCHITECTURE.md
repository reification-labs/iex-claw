# ARCHITECTURE.md — IExClaw Architectural Principles

*Living doc. Updated as principles earn their names through use.*

Last updated: 2026-04-05

---

## Core Taxonomy

### Agent vs. NPC vs. Storefront

| Kind | Has soul? | Uses LLM? | Purpose |
|------|-----------|-----------|---------|
| **Agent** | yes | yes | Judges, decides, acts with agency (Code, Goal, Project) |
| **NPC** | no | usually no | Deterministic service (TodoList, MAP, AgentLogger, MemoryPruner, future Postmaster) |
| **Storefront** | no | no | **Per-Agent handle** wrapping an NPC or substrate. Each Agent owns its own instance. |

**Agents don't manage their own substrate.** They delegate to Storefronts.

A Storefront is the Agent's private doorway into a shared service. Examples:
- **TodoList Storefront** — each Agent's personal task board (Eisenhower-matrixed)
- **Git Storefront** — each Agent's worktree, branch, commit mechanism
- **Filesystem Storefront** — scoped reads/writes for that Agent (future: worktree-backed)
- **Inbox Storefront** — that Agent's messages/inbox/ projection

Agents do judgment. Storefronts do plumbing. NPCs do the shared work underneath.

---

## Context Block Protocol (CBP)

*A structured system-prompt protocol for LLM-powered Agents.*

**The problem:** Flat system prompts stuff everything into one blob. Agents can't triage; they drown. Context-window limits hit before thinking happens.

**The insight:** Context is a workspace with sections, not a room with walls. Each section has a **budget, bid, charge**, and **apply** cycle.

### Block Types (draft)

| Block | Freshness | Typical size | Who writes |
|-------|-----------|--------------|------------|
| **soul** | cold (rare) | large | the Agent itself |
| **role** | cold | medium | ToolRegistry (auto) |
| **inbox** | hot | small (headers only) | Inbox Storefront |
| **todo** | warm | small (headers only) | TodoList Storefront |
| **recent** | warm | small | lineage from logs (growths, verdicts, commits) |
| **peers** | hot | tiny | who's active + last ping |
| **scope** | hot | tiny | what I can touch this turn |
| **clock** | hot | tiny | time, heartbeat tick, since-last-wake |
| **reflection** | warm | small | open lessons from previous sessions |
| **task** | hot | variable | the triggering user message |

### Economic Model (Conroy's coining)

1. **Budget** — each block has a max token allocation
2. **Bid** — each block bids based on urgency × importance × recency
3. **Approve** — budgeter accepts/rejects based on turn priority
4. **Charge** — actual tokens counted after assembly
5. **Apply** — final context window compiled

Agents **auction for pixels**. Like the Million Dollar Homepage, but for context windows.

### Headers Over Bodies

Inbox items and todos appear as **frontmatter-only headers** in the context, not bodies.
Frontmatter fields (example):

```yaml
from: goal
subject: growth-4-completion
urgency: high
importance: high
blocking: true
addressed_to: code
age: 2h
flavor: suggestion
```

The Agent reads headers, **decides what to fetch**, then asks its Storefront for the body.
This is the same pattern as an email client (list view → open).

---

## Bus Architecture (DIRT-backed)

**Messages live at main (outside worktrees).** They are the transport layer.
- Worktrees = rooms (private, soul lives here)
- Messages = hallway (shared, everyone walks through)

Each message is a `.msg.json` envelope, A2A-shaped:
- Required: id, from, to, task_id, timestamp, parts
- Optional: in_reply_to, expects_response

Part kinds: `text`, `file_ref`, `verdict`, `feedback`, `ping`, `ack`, `structured`.

**Status lifecycle** (recipient-managed): unread/read/addressed/replied/archived/waiting/irrelevant/refused.

**Future:** Postmaster NPC fires wake-messages per subscription's `wake_on` contract.

See [MESSAGES.md](MESSAGES.md).

---

## Worktree-Per-Agent (planned, not built)

**Layout:** `projects/iex-claw/.worktrees/<slug>/` (gitignored)
**Branches:** `agents/<slug>` persistent per agent
**Lifecycle:** ephemeral worktree per wake, persistent branch
**Scope enforcement:** whole-tree READ via worktree, narrow WRITE via ScopeGuard
**Merge flow:** agent commits on branch → writes merge_request message → Goal verdicts → GitAgent merges

Each Agent accesses this via their **Git Storefront**. Agents don't `git worktree add` themselves.

---

## Just Do The Next Right Thing

*Ralph Wiggum Loop / "Frozen 2" / "Haz lo que debes"*

Agent wake contract:
1. Assemble context blocks (CBP)
2. Look at inbox header block first
3. If unread mail: address it (or status-change it)
4. Otherwise: consult todo block, pick highest urgency+importance
5. Do the next right thing
6. Sleep

Heartbeat ticks drive the loop. No grand planning. Just the next right thing.

---

## Growth Log

This doc lives. Additions over time:

- **2026-04-05 (born):** Agent/NPC/Storefront taxonomy, Context Block Protocol (CBP) draft, worktree plan
  (conversations with Conroy during the Goal-embodiment + first-round-trip + NVC-feedback session)
