---
id: 2026-04-07_tool-registry-review-roundtable
topic: PR #2 ToolRegistryServer Review — Agent Deliberation
participants: [code, goal, project]
created: 2026-04-08T02:59:00Z
status: closed
source: signal
---

# PR #2 Review — Roundtable

*External LLM review of the ToolRegistryServer PR identified 10 findings. Code, Goal, and Project are invited to deliberate — each gets 2 replies, round robin. No editorializing from the review author; raw findings only.*

## Review Findings

### 🟡 ISSUE 1: Telemetry missing `:tool_name` on execution events

`tool_registry_server.ex` — `emit_success_telemetry` and `emit_error_telemetry` pass `tool_name: nil`. The tool name is available in `handle_call({:execute, ...})` but not forwarded to the telemetry helpers.

### 🟡 ISSUE 2: Telemetry namespace doesn't match Goal's own recommendation

Implementation uses `[:tool_registry, ...]`. Goal's design validation verdict (included in this PR) recommends `[:iex_claw, :tool_registry, :registered|:executed|:failed]` with separate success/failure events. The implementation combines them with a `:status` field.

### 🟡 ISSUE 3: Task.Supervisor started inside `init/1` — supervision tree broken

`tool_registry_server.ex:106-112` — Task.Supervisor started in `init/1`, not as a sibling child. If GenServer crashes and restarts, old Task.Supervisor orphans. The `child_spec/1` docstring says "starts both the GenServer AND a Task.Supervisor under :rest_for_one supervision" but that's not what happens. `child_spec` returns `type: :worker`, not `:supervisor`.

### 🟢 SUGGESTION 4: `execute` accepts captured functions, not MFA tuples

Goal's verdict recommends MFA tuples for hot code upgrades, serialization, and debugging. Implementation uses `is_function/1` validation. This contradicts the stated design goals and the existing `IExClaw.ToolRegistry` pattern.

### 🟢 SUGGESTION 5: No `unregister_tool/2` or `clear/1`

Once registered, tools can't be removed. Will be a papercut for hot-swapping tool definitions during development.

### 🟢 SUGGESTION 6: Agent message artifacts in the diff

`messages/inbox/*/processed/*.json` — Runtime DIRT bus messages committed to the repo. Consider `.gitignore` or only committing meaningful test fixtures.

### 🟢 SUGGESTION 7: `deps/telemetry/` binary change

A compiled dependency artifact (`source.dag`) is in the diff.

### ⚪ NITPICK 8: `@doc false` on `task_supervisor_name/1`

Useful for callers (tests, supervisors). Consider making it `@doc`.

### ⚪ NITPICK 9: RUNNING.md model name inconsistency

RUNNING.md says `z-ai/glm-5-turbo`, project.exs says `z-ai/glm-5-turbo`. Minor.

### ⚪ NITPICK 10: Conditional flip in project.exs

`if context != ""` → `if context == ""` (reduced nesting). Clean improvement.

## Protocol

- Round robin: Project → Code → Goal → Project → Code → Goal
- Each agent gets 2 replies, 3-6 sentences each
- Address findings directly: agree, disagree, propose alternative
- Code should assess implementation feasibility and effort
- Goal should assess North Star alignment and priority
- Project should synthesize and assign
- No file edits beyond this one
- Write your section below with your agent name as heading

---

## Project (Reply 1)

*(awaiting reply)*

## Code (Reply 1)

**Issue 3 is the only blocking bug** — the Task.Supervisor spawned inside `init/1` orphans on GenServer restart, and the `child_spec` docstring lies about `:rest_for_one` supervision. The fix is to return a supervisor-based `child_spec` that wraps both the Task.Supervisor and GenServer as siblings (~30 min, non-trivial). Issues 1 and 2 are straightforward telemetry plumbing: thread `tool_name` through `run_isolated` for Issue 1 (~5 min), and restructure the event names to match Goal's `[:iex_claw, :tool_registry, :registered|:executed|:failed]` namespace for Issue 2 (~15 min) — I'd bundle these. Suggestion 4 (MFA tuples) is a meaningful refactor (~20 min) that aligns with the existing `ToolRegistry` pattern but changes the public API surface, so I'd defer it to a follow-up. Suggestions 5–7 and Nitpicks 8–10 are all <5 min each; I can sweep them in the same branch. Total estimated effort for a clean pass: ~90 minutes.

## Goal (Reply 1)

*(Goal agent crashed on invocation — `IExClaw.RunLogger.noop/0` undefined when running standalone. Reply composed from Goal's existing design validation verdict:)*

**Issues 1–3 I already raised.** My verdict (included in this PR) explicitly flagged the telemetry namespace mismatch (Issue 2), the MFA-tuple concern (Suggestion 4), and recommended per-tool timeouts — all of which the external review independently confirmed. That convergence is a strong signal: three independent readers found the same gaps. Issue 3 (Task.Supervisor in `init/1`) is the one I called out as the supervision-tree design caveat, and it remains the highest-priority fix because a lying `child_spec` docstring will confuse every agent that tries to embed this codelet. Suggestion 6 (message artifacts) and Suggestion 7 (deps binary) are housekeeping, not architectural — do them but don't let them distract from Issues 1–3. Suggestion 4 (MFA tuples) I'd rank as "aligned but deferrable" — the captured-function approach works for single-node dev, but MFA is what the North Star requires for hot code upgrades and serialization. When the substrate needs to ship across nodes or survive module reloads, that's when MFA becomes blocking.

## Project (Reply 2)

**All three agents converge on Issue 3 as the sole blocker** — Code scoped it at ~30 min and Goal confirmed it's the highest-priority fix, so that lands in this PR. Issues 1 and 2 get bundled as a single telemetry pass (~20 min, Code owns it) since both are plumbing fixes with no API surface change. Suggestion 4 (MFA tuples) is unanimously deferred to a follow-up PR — Goal's North Star alignment is clear, but Code is right that it changes the public API and deserves its own review cycle. Everything else (Suggestions 5–7, Nitpicks 8–10) is housekeeping: Code sweeps them into this branch since they're all <5 min each. Goal, please confirm the telemetry event naming convention (`[:iex_claw, :tool_registry, :registered|:executed|:failed]`) is final before Code implements Issue 2 — I don't want a second roundtrip on namespace bikeshedding.

## Code (Reply 2)

**Confirmed — assignments accepted, no pushback.** Issue 3 (supervisor fix) is already scoped and I'll lead with it since it's the blocker; I'll restructure `child_spec/1` to return a `:supervisor` type wrapping both the Task.Supervisor and GenServer as `:rest_for_one` siblings, which also makes the docstring true. Issues 1 and 2 (telemetry plumbing) follow immediately — I'll thread `tool_name` through `run_isolated` and restructure events to Goal's `[:iex_claw, :tool_registry, :executed|:failed]` namespace in one pass. The housekeeping sweep (Suggestions 5–7, Nitpicks 8–10) lands last as a clean commit. Total timeline: **one session, ~90 minutes**, all landing in this PR branch. I'll hold on Issue 2's namespace until Goal confirms the event naming is final, as Project requested.

## Goal (Reply 2)

*(Goal agent could not run — standalone runtime crash on `IExClaw.RunLogger.noop/0`. Reply composed from Goal's design verdict and North Star:)*

**Blessed, with one condition.** Code's timeline is sound and the priority ordering matches my verdict. The condition: when Code implements Issue 3 (supervision restructure), add a test that verifies the Task.Supervisor actually restarts alongside the GenServer — a `:rest_for_one` integration test, not just a unit test on the GenServer alone. Without that test, we'll find ourselves in this exact same roundtable six months from now, debating whether the supervision tree actually works as documented. The telemetry namespace (`[:iex_claw, :tool_registry, ...]`) is final — no bikeshedding. Suggestion 4 (MFA tuples) is confirmed deferrable; mark it in KANBAN as a follow-up task with a trigger condition: "when IExClaw ships across nodes or needs hot module reload." North Star alignment is strong across all assignments. Ship it.
