# MAP — lib/iex_claw/ Module Index

**Generated:** 2026-04-06T00:10:00Z
**Asked by:** Clawd (for tick_refactor)
**Question:** What compiled modules exist in lib/iex_claw/ and what are their public APIs?

## Module Tree

```
lib/iex_claw/
├── agent.ex              (5,286 bytes) — Agent behaviour + helpers
├── llm_client.ex         (2,830 bytes) — OpenAI-compatible LLM adapter
├── tickable.ex           (842 bytes)   — Tickable behaviour
├── tool_registry.ex      (2,366 bytes) — Shared tool registry
├── strategies/
│   └── plan_execute.ex   (6,887 bytes) — PlanExecute strategy
├── tick/
│   └── pump.ex           (2,725 bytes) — Tick pump (budget backpressure)
└── tools/
    ├── agent_logger.ex   (1,921 bytes) — Per-agent growth log
    ├── edit_file.ex       — Atomic multi-edit
    ├── file_system.ex     — Read/write/list/size/backup (scope-guarded)
    ├── messages.ex        (6,739 bytes) — DIRT bus messaging
    └── scope_guard.ex     — Path boundary enforcement
```

## Public APIs (for agents delegating to lib/)

### IExClaw.ToolRegistry
- `as_openai_tools(tools_map, optional_params \\ [])` → `[map()]`
- `execute(tools_map, name, args)` → whatever the tool returns

### IExClaw.LLMClient
- `call(model, messages, tools, opts)` → `{:tool_calls, tcs, msg} | {:message, content} | {:error, reason}`
  - Required opt: `:api_key`
  - Optional: `:base_url`, `:temperature`, `:max_tokens`, `:timeout`

### IExClaw.Agent (behaviour)
- Callbacks: `tools/0`, `optional_params/0`, `system_prompt/1`, `home/0`, `workplace/0`
- Helpers:
  - `load_soul_docs(home, extra_files \\ [])` → `String.t()`
  - `agent_loop(state, execute_fn, opts)` → `agent_state()`
  - `append_message(state, role, content)` → `agent_state()`
  - `extract_summary(state)` → `String.t()`

### IExClaw.Tickable (behaviour)
- Callback: `tick(state, meta)` → `{:work, summary, state} | {:idle, state}`
- meta always contains `:clock` (ISO-8601 UTC)

### IExClaw.Tick.Pump
- `cycle(children, budget \\ 10, meta \\ %{})` → `%{worked, idled, skipped, states}`

### IExClaw.Tools.* (all take `workplace` as parameter)
- `ScopeGuard.validate(path, workplace)` → `{:ok, expanded} | {:error, msg}`
- `FileSystem.read_file(path, workplace, offset, limit)` → `{:ok, banner+slice}`
- `FileSystem.write_file(path, workplace, content, overwrite)` → `{:ok, msg}`
- `EditFile.edit(path, workplace, edits)` → `{:ok, msg}`
- `Messages.read_inbox(agent, inbox_base)` → `{:ok, [summary]}`
- `Messages.send_message(from, to, task_id, parts, inbox_base, workplace, opts)` → `{:ok, env}`
- `AgentLogger.log(agent_name, message, log_dir, workplace)` → `{:ok, path}`

---
*LOAM: regenerate when lib/ changes. Cached for agent consumption.*
