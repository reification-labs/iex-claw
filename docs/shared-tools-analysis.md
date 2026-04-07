# Shared Tools Analysis: Code × Goal

**Generated:** 2026-04-05  
**Files compared:**
- `agents/code/code.exs` (942 lines)
- `agents/goal/goal.exs` (714 lines)

---

## 1. Tools.AgentLogger

### Namespace
Both define `Tools.AgentLogger` (top-level, no agent-scoped nesting).

### Public API
| Function | Code | Goal |
|----------|------|------|
| `log/2` | ✅ | ✅ |

### Line counts
- Code: ~15 lines
- Goal: ~15 lines

### Diff summary: **NEAR-IDENTICAL with two differences**

1. **Log dir** — Code uses `IExClaw.Agents.Code.Constants.home()/logs`, Goal uses `IExClaw.Agents.Goal.Constants.home()/logs`. Same structure, different base path.
2. **Running log filename** — Code writes to `growth.md`, Goal writes to `consultations.md`.
3. **Entry format** — Code: `[timestamp] message\n`. Goal: `[timestamp] [agent_name] message\n` (includes agent name in entry line).

### Recommendation
- Goal's version is slightly better (includes agent name in the entry line — more useful for debugging).
- **Merge:** accept a `home_dir` parameter (or a `log_dir` + `running_log_name`) so each agent can configure its own paths, but share the formatting and file I/O logic.
- Risk: **Low** — trivial module, no state, no external deps.

---

## 2. Tools.ScopeGuard

### Namespace
Both define `Tools.ScopeGuard` (top-level).

### Public API
| Function | Code | Goal |
|----------|------|------|
| `validate/1` | ✅ | ✅ |
| `validate!/1` | ✅ | ❌ |

### Line counts
- Code: ~15 lines
- Goal: ~10 lines

### Diff summary: **NEAR-IDENTICAL with minor differences**

1. **Workplace constant** — Code reads from `IExClaw.Agents.Code.Constants.workplace()`, Goal from `IExClaw.Agents.Goal.Constants.workplace()`. Both resolve to the same path (`projects/iex-claw/`), but reference different modules.
2. **Error message phrasing** — Code: "I don't work there." Goal: "I don't judge there." Cosmetic only.
3. **`validate!/1`** — Code has a bang variant that raises; Goal does not.

### Recommendation
- Use Code's version (has `validate!/1` which is useful).
- **Parametrize the workplace path** via a module attribute or compile-time config, or accept a `workplace` option. Since both currently resolve to the same path, this is straightforward.
- Risk: **Low** — pure function, single dependency on workplace path string.

---

## 3. Tools.FileSystem

### Namespace
Both define `Tools.FileSystem` (top-level).

### Public API
| Function | Code | Goal |
|----------|------|------|
| `read_file_raw/1` | ✅ | ✅ |
| `read_file/3` | ✅ | ✅ |
| `write_file/3` | ✅ | ✅ |
| `list_dir/1` | ✅ | ✅ |
| `file_size/1` | ✅ | ✅ |
| `backup/1` | ✅ | ❌ |

### Line counts
- Code: ~95 lines
- Goal: ~75 lines

### Diff summary: **NEAR-IDENTICAL except Code has `backup/1`**

1. **`backup/1`** exists only in Code. Creates a timestamped `.backup.<date>` copy. Goal doesn't need it (Goal doesn't do destructive file ops).
2. **`write_file/3` error message** — Code: "Use overwrite:true to clobber. (Show me what's there first.)" Goal: "Use overwrite:true to clobber." Code's has personality.
3. All other functions are byte-for-byte identical in logic.

### Recommendation
- **Use Code's version** (superset — includes `backup/1`).
- No API changes needed. Goal can simply not register `backup` in its ToolRegistry.
- Risk: **Low** — all functions delegate to `Tools.ScopeGuard.validate/1` which is already being shared.

---

## 4. Tools.EditFile

### Namespace
Both define `Tools.EditFile` (top-level).

### Public API
| Function | Code | Goal |
|----------|------|------|
| `edit/2` | ✅ | ✅ |

### Line counts
- Code: ~50 lines
- Goal: ~45 lines

### Diff summary: **IDENTICAL in logic, minor formatting differences**

1. The `validate_edits/2` final clause uses `if/else` in Code vs `do/end, else:` in Goal. Same behavior.
2. Everything else (normalization, `count_occurrences`, `do_count`, `apply_edits`) is identical.

### Recommendation
- **Either version works.** Use Code's (slightly more explicit formatting).
- No API changes needed.
- Risk: **Low** — depends on `ScopeGuard` and `FileSystem.read_file_raw`, both shared.

---

## 5. ToolRegistry

### Namespace
Both define `ToolRegistry` (top-level).

### Public API
| Function | Code | Goal |
|----------|------|------|
| `all/0` | ✅ | ✅ |
| `as_openai_tools/0` | ✅ | ✅ |
| `execute/2` | ✅ | ✅ |

### Line counts
- Code: ~100 lines
- Goal: ~95 lines

### Diff summary: **DIFFERENT — tool sets diverge**

1. **Tool sets differ:**
   - **Code-only tools:** `backup`, `read_inbox`, `read_message`
   - **Goal-only tools:** `render_verdict`
   - **Both share:** `read_file`, `write_file`, `edit_file`, `list_dir`, `file_size`, `send_message`

2. **`send_message` dispatch differs:**
   - Code's `execute/2` dispatches `send_message` through the generic path (positional args via params list).
   - Goal has a special-case `execute("send_message", args)` that passes the whole `args` map to `Tools.Messages.send_message/1`.

3. **`as_openai_tools/0`:** Code's optional param exclusion is a hardcoded list of `["overwrite", "offset", "limit"]`. Goal's is `["overwrite", "from", "in_reply_to", "expects_response", "offset", "limit"]` (broader). Goal's is more correct.

4. **Tool descriptions** differ slightly to match each agent's persona (e.g., Goal's `write_file` says "Prefer render_verdict for judgments").

### Recommendation
- **Do NOT extract as-is.** The tool sets are agent-specific; the registry *should* be per-agent.
- **Extract the infrastructure** (`as_openai_tools/0` logic, `execute/2` generic dispatch) into a shared module (e.g., `ToolRegistry.Base` or a `ToolRegistry.build/1` that takes a tool map). Each agent calls it with its own `@tools` map.
- Unify the optional-params list (use Goal's broader list).
- Risk: **Medium** — the dispatch mechanism touches LLM integration; get it wrong and tools break silently.

---

## 6. Tools.Messages

### Namespace
Both define `Tools.Messages` (top-level).

### Public API
| Function | Code | Goal |
|----------|------|------|
| `read_inbox/0` | ✅ | ❌ |
| `read_message/1` | ✅ | ❌ |
| `send_message/4` | ✅ (positional) | ❌ |
| `send_message/1` | ❌ | ✅ (map arg) |

### Line counts
- Code: ~130 lines (full inbox read + send)
- Goal: ~35 lines (send only)

### Diff summary: **DIFFERENT — Code is much more complete**

1. Code has `read_inbox/0` (list inbox with summaries), `read_message/1` (parse single message), and `send_message/4` (positional args with opts keyword list).
2. Goal has only `send_message/1` (takes a single map arg).
3. Code's `send_message` does **ScopeGuard validation** on the recipient inbox path; Goal's does not.
4. Code's `send_message` uses helper functions (`build_envelope`, `generate_message_id`, `summarize_message`, etc.); Goal's is inline and simpler.
5. Code hardcodes `"from" => "code"`; Goal uses `Map.get(args, "from", "goal")`.

### Recommendation
- **Use Code's version as the base** — it's the full implementation with inbox reading, proper validation, and well-factored helpers.
- **Generalize:** the `"from"` field should be parameterized (not hardcoded to `"code"`). Either pass it as an arg or set it via module attribute.
- **Remove ScopeGuard from send_message** (or make it optional) — the recipient inbox is always inside the workplace, so the guard is redundant for writing to known paths, but Goal skipping it entirely is a gap.
- Risk: **Medium** — the `"from"` hardcoding is the main concern; easy to fix.

---

## Modules Unique to One File

### Code-only
- **`IExClaw.Agents.Code.Constants`** — agent-specific (home = `agents/code/`). Not shared.
- **`IExClaw.Agents.Code`** (GenServer) — agent-specific. Not shared.
- **`backup/1` in Tools.FileSystem** — noted above; include in shared FileSystem.

### Goal-only
- **`IExClaw.Agents.Goal.Constants`** — agent-specific. Not shared.
- **`IExClaw.Agents.Goal`** (GenServer) — agent-specific. Not shared.
- **`Tools.Verdict`** — Goal-specific. Not a candidate for shared (too domain-specific), unless future agents also render verdicts.

### Cross-cutting pattern: GenServer agent loop
Both `IExClaw.Agents.Code` and `IExClaw.Agents.Goal` share ~90% identical GenServer boilerplate:
- `start_link/1`, `start/1`, `request/2`, `run/2`
- `init/1` (model, api_key, base_url, soul_docs)
- `agent_loop/1`, `call_llm/1`, `format_args/1`, `append_message/3`, `extract_summary/1`

**This is the biggest shared abstraction opportunity.** A `IExClaw.Agent.Base` GenServer that accepts:
- agent name (for logging)
- soul doc loader function
- system prompt template
- tool registry module

...would eliminate ~60-70% of the duplication between agents.

**Risk: Medium-High** — the agent loop is the core runtime; bugs here affect everything. Defer until after tools are extracted.

---

## Recommended Extraction Order

| Priority | Module | Risk | Why |
|----------|--------|------|-----|
| 1 | **Tools.ScopeGuard** | Low | Tiny, no deps, both identical. Quick win. Parametrize `@workplace`. |
| 2 | **Tools.AgentLogger** | Low | Tiny, one function. Accept `home` + `running_log_name` params. |
| 3 | **Tools.FileSystem** | Low | Straight superset extract (Code's version). Depends on ScopeGuard. |
| 4 | **Tools.EditFile** | Low | Identical logic. Depends on ScopeGuard + FileSystem. |
| 5 | **Tools.Messages** | Medium | Code's version is the base; generalize `"from"` field. Depends on ScopeGuard. |
| 6 | **ToolRegistry (infra)** | Medium | Extract `as_openai_tools/0` and generic `execute/2`. Each agent keeps its own `@tools` map. |
| 7 | **Agent GenServer base** | Medium-High | Biggest leverage but most risk. Defer until tools are stable. |
| — | Tools.Verdict | N/A | Goal-specific. Skip unless verdict-rendering becomes a cross-agent pattern. |

**Phase 1 (do now):** Items 1–4. Low risk, high leverage, unambiguous.
**Phase 2 (next):** Item 5–6. Medium risk, requires careful API design.
**Phase 3 (defer):** Item 7. Requires multiple agents to validate the abstraction.
