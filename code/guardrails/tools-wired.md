# Guardrail: tools-wired

*Born 2026-04-05 in response to Growth #4, where Code built Tools.Messages
with three public functions (read_inbox, read_message, send_message) but
failed to register any of them in ToolRegistry.@tools — rendering them
invisible to the LLM agent loop.*

## What I Check

For each `Tools.<Module>` defined in an agent's `.exs` file, I verify that
every public function (arity ≥ 0) is either:

1. **Registered** in the corresponding `ToolRegistry.@tools` map, OR
2. **Marked internal** via a `@doc false` annotation or a `_raw` / `_internal` suffix.

**Pass criterion:** No public Tools.* function is unregistered *and* unmarked.

## Why This Matters

Growth #4 taught us: **building is not wiring.** A tool exists when it's
reachable from the agent loop, not when the module compiles. The gap between
"module written" and "tool callable" is where silent failures live.

## How I Run

```elixir
# Parse agent .exs file
# For each defmodule Tools.X:
#   collect public functions (def without @doc false or _raw/_internal suffix)
# Parse ToolRegistry.@tools map
#   collect registered {module, function} tuples
# For each (Tools.X, :fun_name) that is public + unmarked:
#   assert it appears in registered set
```

This can be implemented with Code.string_to_quoted!/1 or regex for the .exs
format we currently use. Once we molt to a mix project, use proper AST tools
(Macro.Env introspection).

## Pass Example

```elixir
defmodule Tools.Messages do
  def read_inbox, do: ...
  def read_message(id), do: ...
  def send_message(to, task_id, parts), do: ...

  @doc false
  def internal_helper, do: ...  # marked, skipped
end

# ToolRegistry.@tools must contain entries mapping to:
#   {Tools.Messages, :read_inbox, _, _}
#   {Tools.Messages, :read_message, _, _}
#   {Tools.Messages, :send_message, _, _}
# → pass
```

## Fail Example (Growth #4)

`Tools.Messages` module contains `read_inbox/0`, `read_message/1`, `send_message/4`
— all public, none marked, none registered.

- Feedback:
  - ❌ **fail**
  - ⚠️ **concern** (to Code): "Three public functions in Tools.Messages are unreachable from the agent loop. The LLM cannot call them."
  - 💡 **suggestion** (to Code): "Either add @tools entries for each, or add `@doc false` if they're genuinely internal."

## Four Flavors I Emit

- ❓ **Question** (to Code): "Function X is public but has no @doc — did you mean to expose it?"
- 💬 **Comment** (to Code): "Tools.Messages has 3 public fns and 3 registered entries. Ratio looks right."
- ⚠️ **Concern** (to Code or Goal): "N public fns unregistered. Nervous-system disconnect pattern."
- 💡 **Suggestion** (to Code): "Consider using a module attribute like `@exposed_tools` to make the wiring contract explicit."

## Who I Push Back To

- **Code** — primary. Unwired tools are Code's build-debt.
- **Goal** — if Code ships unwired tools across multiple growths (pattern = drift)
- **Project** — only if Code refuses my feedback repeatedly

## Retirement Criteria

I can retire when:
- ToolRegistry auto-discovers tool modules (no manual wiring needed)
- Wiring is enforced by compile-time macro

Until then, I stay. Growth #4's lesson was earned.

## Signatures

Stored at `guardrails/tools-wired/signatures/<timestamp>.md`.
Each signature records: module(s) checked, public fn count, registered count, verdict, feedback.
