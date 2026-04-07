# MAP — code.exs Section Map

**Generated:** 2026-04-06T00:10:00Z
**Asked by:** Clawd (for tick_refactor / Code's self-surgery)
**Question:** What are the major sections in agents/code/code.exs, with byte offsets and line numbers?
**File:** `agents/code/code.exs` (20,475 bytes, ~640 lines)

## Section Index

| Lines | Bytes | Module / Section | Status |
|-------|-------|-----------------|--------|
| 1-27 | 0-755 | Header + Mix.install | — |
| 28-37 | 756-1354 | `Code.require_file` loaders (5 compiled tools) | ✅ already delegated |
| 38-48 | 1355-1620 | `Constants` (home + workplace) | keep as-is |
| 50-68 | 1621-2207 | `Tools.AgentLogger` (thin delegator) | ✅ already delegated |
| 70-112 | 2208-3601 | `Tools.Messages` (thin delegator) | ✅ already delegated |
| 113-123 | 3602-3987 | `Tools.ScopeGuard` (thin delegator) | ✅ already delegated |
| 125-139 | 3988-4750 | `Tools.FileSystem` (thin delegator) | ✅ already delegated |
| 140-150 | 4751-5072 | `Tools.EditFile` (thin delegator) | ✅ already delegated |
| **152-259** | **5073-9471** | **`ToolRegistry`** — @tools map + `all/0` + `as_openai_tools/0` + `execute/2` | **🔴 REFACTOR TARGET** |
| **261-574** | **9472-18345** | **`IExClaw.Agents.Code`** — GenServer + agent_loop + call_llm + all helpers | **🔴 REFACTOR TARGET** |
| 575-640 | 18346-20475 | CLI wake-up guard + usage banner | keep as-is |

## Refactor Targets (detail)

### ToolRegistry (lines 152-259, ~4400 bytes)

- **@tools map** (lines 156-221): Agent-specific tool definitions. KEEP INLINE — each agent has different tools.
- **all/0** (line 223): `def all, do: @tools` — trivial, keep.
- **as_openai_tools/0** (lines 225-248): OpenAI schema formatting. **REPLACE** with `IExClaw.ToolRegistry.as_openai_tools(@tools, ~w[overwrite offset limit])`.
- **execute/2** (lines 250-259): Tool dispatch. **REPLACE** with `IExClaw.ToolRegistry.execute(@tools, name, args)`.

### IExClaw.Agents.Code GenServer (lines 261-574, ~8900 bytes)

- **struct + public API** (lines 264-310): `start_link`, `start`, `request`, `run` — keep as-is (agent-specific).
- **load_soul_docs/0** (lines 314-326): **REPLACE** with `IExClaw.Agent.load_soul_docs(Constants.home())`.
- **system_prompt/1** (lines 330-393): Agent-specific. KEEP (each soul is unique).
- **init/1** (lines 397-418): Uses load_soul_docs + system_prompt. Partially delegate.
- **handle_call** (lines 420-440): Agent-specific log + agent_loop call. Keep, but call shared loop.
- **agent_loop/1** (lines 456-500): LLM tool-call loop. **REPLACE** with `IExClaw.Agent.agent_loop/3`.
- **format_args/1** (lines 502-512): Private helper. Moves into Agent module.
- **call_llm/1** (lines 516-553): HTTP call to OpenRouter. **REPLACE** with `IExClaw.LLMClient.call/4`.
- **append_message/2** (line 555): **REPLACE** with `IExClaw.Agent.append_message/3`.
- **extract_summary/1** (lines 557-565): **REPLACE** with `IExClaw.Agent.extract_summary/1`.

## lib/ Module APIs (what Code delegates to)

### IExClaw.ToolRegistry (lib/iex_claw/tool_registry.ex)
```elixir
as_openai_tools(tools_map, optional_params \\ []) :: [map()]
execute(tools_map, name, args) :: term()
```

### IExClaw.LLMClient (lib/iex_claw/llm_client.ex)
```elixir
call(model, messages, tools, opts) :: {:tool_calls, ...} | {:message, ...} | {:error, ...}
# opts: api_key (required), base_url, temperature, max_tokens, timeout
```

### IExClaw.Agent (lib/iex_claw/agent.ex)
```elixir
load_soul_docs(home, extra_soul_files \\ []) :: String.t()
agent_loop(state, execute_fn, opts) :: agent_state()
# execute_fn: fn(name, args) -> term()
# opts: tools_schema, agent_name
append_message(state, role, content) :: agent_state()
extract_summary(state) :: String.t()
```

## Suggested Edit Plan (for PlanExecute)

1. Add `Code.require_file` for `tool_registry.ex`, `llm_client.ex`, `agent.ex` at top (3 new lines)
2. Replace `as_openai_tools/0` body (lines 225-248) with one-liner delegation
3. Replace `execute/2` body (lines 250-259) with one-liner delegation
4. Replace `load_soul_docs/0` body (lines 314-326) with one-liner delegation
5. Replace `agent_loop/1` + `format_args/1` + `call_llm/1` + `append_message/2` + `extract_summary/1` (lines 456-565) with delegations to IExClaw.Agent + IExClaw.LLMClient
6. Verify: file_size should drop from 20,475 to ~12,000-14,000 bytes

---
*Suggested follow-up: generate same map for goal.exs (same refactor, different tools)*
