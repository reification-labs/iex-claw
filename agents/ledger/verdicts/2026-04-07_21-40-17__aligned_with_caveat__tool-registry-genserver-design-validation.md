# Verdict: aligned_with_caveat

**Subject:** tool-registry-genserver-design-validation
**Rendered:** 2026-04-07T21:40:17.724354Z
**Agent:** Goal

---

## Verdict: Aligned with Caveat

The proposed ToolRegistry GenServer design is **sound OTP** and moves us toward the North Star (model-agnostic substrate, standalone first, souls before behavior). The KANBAN already flags "Tool registry as shared protocol" as hot — this is the design for that task. But I have specific guidance on each of the four questions.

---

### 1. `async_nolink` + `yield`/`shutdown` — YES, this is the right pattern

**Verdict: Aligned. Ship it as proposed.**

This is the canonical Elixir idiom for "run something that might explode, but don't let it take me down." The Elixir docs, José's blog posts, and every production codebase I've seen use this exact pattern for fire-and-forget-with-timeout work.

Why it beats `try/rescue` in a linked task:

- **`try/rescue` only catches exceptions**, not exits. If a task links to something that sends an `:EXIT` signal, the rescue is bypassed entirely. False security.
- **`async_nolink` provides true isolation** — the task's crash domain is completely severed from the caller and the registry GenServer. No exit signal propagation, period.
- **`yield`/`shutdown` gives you clean timeout semantics** that `try/rescue` cannot. You get `{:exit, reason}` on crash and `nil` on timeout — two distinct failure modes you can map to different error responses.
- **`shutdown(:brutal_kill)` is the right cleanup** for tool execution. Tools shouldn't have persistent state that needs graceful shutdown. If a tool is stuck, kill it.

The "slightly more complex" argument against `async_nolink` is a complexity *tax*, not a complexity *cost*. You pay it once in the registry, and every tool gets crash isolation for free. That's the right trade.

**One caveat**: Make sure `Task.yield` timeout is configurable per-tool or per-call, not hardcoded. Some tools (web fetches) legitimately need longer than others (filesystem ops). The tool def shape should support a `timeout` field (defaulting to something sane like 30s).

---

### 2. Task.Supervisor as sibling under `:rest_for_one` — ALIGNED, with a nuance

**Verdict: Aligned. The sibling approach is correct.**

The proposed `:rest_for_one` with `[Task.Supervisor, GenServer]` ordering means:
- Task.Supervisor crashes → GenServer restarts (clean slate, no orphaned tasks) ✅
- GenServer crashes → Task.Supervisor survives, in-flight tasks complete or timeout naturally ✅

This is the right call. Making the Task.Supervisor a *child* of the GenServer would be an anti-pattern:
- GenServer crash kills the supervisor → kills all in-flight tasks → wasteful
- GenServer restart → must restart supervisor → must restart all task infrastructure → slow recovery

**The nuance**: When the GenServer crashes and restarts, the old Task.Supervisor still has tasks running from the previous GenServer incarnation. These tasks will complete or timeout, but their results are orphaned — the new GenServer has no reference to them. This is fine *because* `async_nolink` means the GenServer wasn't waiting on them synchronously anyway. The `yield`/`shutdown` pattern already handles this: the caller got their response (or timeout) before the GenServer crashed.

**Alternative considered**: `:one_for_one` supervision. This would also work — the GenServer and Task.Supervisor are independent. But `:rest_for_one` is slightly better because it ensures the GenServer always starts with a fresh Task.Supervisor after a supervisor crash, preventing edge cases where the Task.Supervisor is in a bad state.

**Recommendation**: Keep the sibling + `:rest_for_one` design. Name the Task.Supervisor (e.g., `IExClaw.ToolRegistry.TaskSupervisor`) so the GenServer can reference it by name after restart.

---

### 3. Telemetry naming — CAVEAT: namespace under the application

**Verdict: Aligned with caveat.**

The proposed `[:tool_registry, :tool_registered]` and `[:tool_registry, :tool_executed]` follow the `[:prefix, :event]` convention, which is correct. But they're missing the application namespace.

**The convention** (Phoenix, Oban, Ecto, Telemetry itself) is `[:application, :component, :event]`:
- Phoenix: `[:phoenix, :endpoint, :stop]`
- Oban: `[:oban, :job, :stop]`
- Ecto: `[:my_app, :repo, :query]`

**Rewrite**:
```
[:iex_claw, :tool_registry, :registered]   # tool added to registry
[:iex_claw, :tool_registry, :executed]     # tool execution complete
[:iex_claw, :tool_registry, :failed]       # tool execution failed (crash/timeout)
```

Three events instead of two — separate success and failure telemetry. The `:executed` event carries `:status` already, but splitting them makes it trivial to attach different handlers (e.g., alert on failure, meter on success) without filtering in the handler.

**Measurements** for `:executed` / `:failed`:
- `:duration` (integer, monotonic time) — required
- `:tool_name` (string) — metadata, not measurement
- `:status` (`:ok | :error | :timeout | :crash`) — metadata

This is consistent with Oban's pattern where `:duration` is the measurement and everything else is metadata.

---

### 4. Tool def shape — CAVEAT: keep MFA tuples, not captured functions

**Verdict: Rewrite required on this point.**

The proposed `%{description: String.t(), parameters: map(), execute: (map() -> ...)}` uses a captured function for `:execute`. This is simpler to write but has a critical limitation: **captured functions are not serializable**.

The current codebase already uses MFA tuples — look at `IExClaw.ToolRegistry`:
```elixir
@type tool_entry :: {module(), atom(), String.t(), [param()]}
# "tool_name" => {module, function, description, params}
```

And `IExClaw.Agent` behaviour:
```elixir
@callback tools() :: IExClaw.ToolRegistry.tools_map()
```

**Why MFA tuples matter for IExClaw**:
1. **Hot code upgrades** — the BEAM's superpower. MFA tuples resolve at call time, so upgraded modules are picked up automatically. Captured functions capture the module version at capture time.
2. **Serialization** — tool definitions become pure data. You can persist them, inspect them, log them, send them across nodes.
3. **Debugging** — `apply(IExClaw.Tools.FileSystem, :read_file, args)` tells you exactly what's being called. A captured function is opaque.
4. **Consistency** — the existing codebase is already MFA-shaped. Adding a second shape creates a bifurcation that will confuse every agent.

**Rewrite the tool def shape**:
```elixir
%{
  name: String.t(),
  description: String.t(),
  parameters: [param()],
  execute: {module(), atom()},  # MFA without args — args come from the call
  timeout: non_neg_integer()    # NEW — per-tool timeout for yield
}
```

Where `param()` is:
```elixir
%{name: String.t(), type: String.t(), description: String.t()}
```

The GenServer's `execute_tool/2` would do:
```elixir
{mod, fun} = tool_def.execute
apply(mod, fun, [args])
```

This preserves the existing pattern while adding the GenServer statefulness (registration, listing, crash isolation, telemetry).

---

### Summary

| Question | Verdict | Action |
|----------|---------|--------|
| async_nolink + yield/shutdown | ✅ Aligned | Ship as proposed. Add per-tool timeout. |
| Task.Supervisor sibling vs child | ✅ Aligned | Keep sibling + `:rest_for_one`. Name the supervisor. |
| Telemetry naming | ⚠️ Caveat | Namespace under `:iex_claw`. Split success/failure events. |
| Tool def shape | 🔄 Rewrite | Keep MFA tuples. Add `:timeout` field. Don't use captured functions. |

**No drift detected.** This is infrastructure that serves the North Star — it makes tools safer (crash isolation), more observable (telemetry), and more maintainable (shared registry). It's the natural evolution from the current stateless `IExClaw.ToolRegistry` module to a stateful GenServer, which is exactly what the KANBAN's "Tool registry as shared protocol" task calls for.

**One watchpoint for Project**: The existing `IExClaw.ToolRegistry` module (stateless utility) and the new GenServer-backed registry need a clear migration path. The utility functions (`as_openai_tools/2`, `execute/3`) should probably be extracted into the GenServer or kept as a thin delegation layer. Don't leave two competing tool registry abstractions in the codebase.

---
*The North Star doesn't move. I move the map.*
