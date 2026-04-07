# MAP — lib/iex_claw/ Module Index

**Generated:** 2026-04-07T21:35:00Z
**Asked by:** Clawd
**Question:** What compiled modules exist in lib/iex_claw/ and what are their public APIs?

## Module Tree

```
lib/iex_claw/
├── agent.ex                  (6,294 bytes) — Agent behaviour + helpers
├── contract.ex               (5,470 bytes) — Contract state machine (attempts, modes, checkpoints)
├── llm_client.ex             (2,822 bytes) — OpenAI-compatible LLM adapter
├── mode.ex                   (3,022 bytes) — Mode definition + tool filtering
├── run_logger.ex             (4,000 bytes) — Per-run event logging (JSONL)
├── strategies/
│   └── plan_execute.ex       (6,903 bytes) — PlanExecute strategy (think→plan→execute→verify)
├── tick/
│   └── pump.ex               (2,677 bytes) — Tick pump (budget backpressure)
├── tickable.ex               (844 bytes)   — Tickable behaviour
├── tool_registry.ex          (2,366 bytes) — Stateless tool registry utility
└── tools/
    ├── agent_logger.ex       (1,910 bytes) — Per-agent growth log
    ├── edit_file.ex          (2,875 bytes) — Atomic multi-edit
    ├── file_system.ex        (4,831 bytes) — Read/write/list/size/backup (scope-guarded)
    ├── messages.ex           (6,712 bytes) — DIRT bus messaging (inbox/send)
    ├── scope_guard.ex        (1,549 bytes) — Path boundary enforcement
    └── submit_plan.ex        (1,952 bytes) — Plan submission + validation
```

## Public APIs (for agents delegating to lib/)

### IExClaw.Agent (behaviour)
- Callbacks: `tools/0`, `optional_params/0`, `system_prompt/1`, `home/0`, `workplace/0`
- Helpers:
  - `load_soul_docs(home, extra_files \\ [])` → `String.t()`
  - `agent_loop(state, execute_fn, opts)` → `agent_state()`
  - `append_message(state, role, content)` → `agent_state()`
  - `extract_summary(state)` → `String.t()`

### IExClaw.Contract
- `new(opts)` — create contract with modes, max_attempts
- `start/1`, `advance/1`, `budget_exhausted/1`, `checkpoint/2`, `summary/1`, `active?/1`

### IExClaw.Mode
- `new(name, opts)` — define a mode with tool allowlist
- `filter_tools/2` — filter tool registry to mode's allowed tools

### IExClaw.LLMClient
- `call(model, messages, tools, opts)` → `{:tool_calls, tcs, msg} | {:message, content} | {:error, reason}`
  - Required opt: `:api_key`
  - Optional: `:base_url`, `:temperature`, `:max_tokens`, `:timeout`

### IExClaw.RunLogger
- `generate_run_id(agent, goal_slug)` → run ID string
- `callback/2` → telemetry callback function
- `emit/4` → log event to JSONL
- `noop/0` → silent callback

### IExClaw.Strategies.PlanExecute
- Full plan→execute→verify loop strategy. Used by agents that need multi-step reasoning.

### IExClaw.Tickable (behaviour)
- Callback: `tick(state, meta)` → `{:work, summary, state} | {:idle, state}`
- meta always contains `:clock` (ISO-8601 UTC)

### IExClaw.Tick.Pump
- `cycle(children, budget \\ 10, meta \\ %{})` → `%{worked, idled, skipped, states}`

### IExClaw.ToolRegistry (stateless utility)
- `as_openai_tools(tools_map, optional_params \\ [])` → `[map()]`
- `execute(tools_map, name, args)` → whatever the tool returns
- **Note:** This is the OLD stateless version. A GenServer-backed replacement is in progress.

### IExClaw.Tools.* (all take `workplace` as parameter)
- `ScopeGuard.validate(path, workplace)` → `{:ok, expanded} | {:error, msg}`
- `FileSystem.read_file(path, workplace, offset, limit)` → `{:ok, banner+slice}`
- `FileSystem.write_file(path, workplace, content, overwrite)` → `{:ok, msg}`
- `EditFile.edit(path, workplace, edits)` → `{:ok, msg}`
- `Messages.read_inbox(agent, inbox_base)` → `{:ok, [summary]}`
- `Messages.send_message(from, to, task_id, parts, inbox_base, workplace, opts)` → `{:ok, env}`
- `AgentLogger.log(agent_name, message, log_dir, workplace)` → `{:ok, path}`
- `SubmitPlan.submit(plan_json)` → `{:ok, path} | {:error, reason}`

## Code Style Conventions
- Formatter: 2-space indent, 80 char line limit
- Credo: custom config at `.credo.exs` (see for full rules)
- Tests: `test/iex_claw/` mirrors `lib/iex_claw/` structure
- `@moduledoc` and `@doc` on all public functions
- Typespecs where practical
- No external deps beyond what's in `mix.exs`

## Existing Patterns Worth Following
- **Crash isolation**: Task.Supervisor.async_nolink + yield/shutdown (see Elders roundtable)
- **Scope guarding**: all file ops validate against workplace boundary
- **Atomic edits**: edit_file takes structured edit list, not raw writes
- **DIRT messaging**: file-based envelopes in `messages/inbox/{agent}/`
- **Telemetry**: `[:iex_claw, :agent_name, :event]` namespace (Goal's verdict, not yet implemented)

---
*LOAM: regenerate when lib/ changes. Cached for agent consumption.*
