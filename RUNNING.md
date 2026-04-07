# Running IExClaw from Clawd

Quick reference for operating IExClaw's agent loop from OpenClaw.

## Project Location
`~/workspace/projects/iex-claw/`

## Key Paths (also in `agents/map/maps/lib-iex-claw-modules.md`)
- Agents: `agents/{project,code,goal}/`
- Shared lib: `lib/iex_claw/`
- Tick infrastructure: `agents/tick.exs`, `agents/inbox_tick.exs`, `agents/project_tick.exs`
- Messages (the DIRT bus): `messages/inbox/{project,code,goal}/`
- Processed messages: `messages/inbox/{agent}/processed/`
- Maps (project cartography): `agents/map/maps/`
- Verdicts: `agents/goal/ledger/verdicts/`
- Agent logs: `agents/logs/`
- KANBAN: `KANBAN.md`
- Architecture: `ARCHITECTURE.md`

## Running Ticks

```bash
# Dry run — see what would happen, no LLM calls, no message moves
cd ~/workspace && elixir projects/iex-claw/agents/project_tick.exs --dry-run --budget 2 --max 4

# Live run — agents call LLMs, process messages, delegate
cd ~/workspace && elixir projects/iex-claw/agents/project_tick.exs --budget 2 --max 4

# Flags:
#   --dry-run     read inboxes, don't call LLMs or move messages
#   --budget N    units of work per cycle (default 1)
#   --max N       max cycles before stopping (default 6)
```

## Sending Messages

Drop a file into an agent's inbox directory. Two formats:

### Plain markdown (fallback)
```bash
# Any .md or .txt file works — treated as raw text
echo "# Build the thing\nFull spec here" > messages/inbox/code/001-build-thing.md
```

### Structured JSON (preferred)
```json
{
  "from": "clawd",
  "to": "code",
  "task_id": "build-thing",
  "parts": [
    {"kind": "text", "text": "Build a tool registry GenServer..."},
    {"kind": "text", "text": "Context: see lib/iex_claw/tool_registry.ex"}
  ],
  "expects_response": false
}
```

### Part kinds
- `text` — plain content
- `directive` — `{kind: "directive", directive: "implement", text: "..."}`
- `feedback` — `{kind: "feedback", observation: "...", request: "..."}`
- `verdict` — `{kind: "verdict", verdict_type: "aligned", body: "..."}`
- `file_ref` — `{kind: "file_ref", path: "relative/path", note: "..."}`

## Tick Order (Project owns the clock)
1. **Project** reads inbox → thinks → may send to Code/Goal
2. **Code** reads inbox → reads files → writes/edits code
3. **Goal** reads inbox → reads proposals → renders verdict

Budget determines how many agents can do work per cycle. Budget 1 = one agent per cycle. Budget 3 = all three can work in one cycle.

## Agent Direct Invocation

```bash
# Code — one-shot
cd ~/workspace && elixir projects/iex-claw/agents/code/code.exs "build a thing"

# Goal — one-shot
cd ~/workspace && elixir projects/iex-claw/agents/goal/goal.exs "review this proposal"

# Project — one-shot
cd ~/workspace && elixir projects/iex-claw/agents/project/project.exs "plan the next sprint"
```

## Environment
- `OPENROUTER_API_KEY` — required for LLM calls
- `PROJECT_MODEL` — override model (default: `z-ai/glm-5-turbo`)
- `IEXCLAW_MODEL` — fallback model
- `IEXCLAW_SKIP_DEMO` — set to `1` when loading as library

## Map Files (prevent re-exploration)
Agents should read `agents/map/maps/lib-iex-claw-modules.md` for project structure before exploring. Keep it current when lib/ changes. This is LOAM — cached for agent consumption.
