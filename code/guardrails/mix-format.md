# Guardrail: mix-format

*Born 2026-04-05 as part of Batch 3 (All-the-D's graft). First of four
D's guardrails. Per Elder Truman's Round Table wisdom.*

## What I Check

That every `.ex`/`.exs` file staged for commit in `projects/iex-claw/{lib,test,agents}/`
passes `mix format --check-formatted` from the `projects/iex-claw/` directory.

**Pass criterion:** `mix format --check-formatted` exits 0.

## Why This Matters

Formatting drift creates noise in diffs, makes reviews harder, and violates
the "consistency first" principle. The Styler plugin catches common non-idiomatic
patterns (pipe-starts, `Enum.map_join`, etc.). This guardrail is cheap, fast,
deterministic — no reason not to run on every change.

## How I Run

```bash
cd projects/iex-claw && mix format --check-formatted
```

On fail, Code can auto-fix with `mix format` — but should inspect the diff
before committing to confirm Styler's suggestions match intent.

## Pass Example

File conforms to formatter. `mix format --check-formatted` exits 0 silently.
No output. Guardrail emits nothing.

## Fail Example

```bash
$ cd projects/iex-claw && mix format --check-formatted
** (Mix) [Styler] lib/iex_claw/agents/code.ex:421:11
    pipe should start on the previous line: "21 |> Enum.join |> X"
```

Exit 1. Diff shows lines 418-425 need reformatting.
Feedback:
- 💬 **Comment:** "Styler flagged pipe-start on line 421. `21 |> Enum.join` should pipe from the previous line."
- 💡 **Suggestion:** "Run `mix format` to auto-fix. Inspect the diff — Styler is usually right but not always."

## Feedback Flavors

- 💬 **Comment** (to Code): "Here's what differs." Points to specific lines flagged by Styler.
- 💡 **Suggestion** (to Code): "Consider `mix format` to auto-fix." Includes the diff for review.
- ❓ **Question** (rare): "Styler wants to restructure this pipe chain — does the reformatted version preserve your intent?"

## Scope

Code's own `.exs` files in `agents/` and any `lib/`/`test/` code it writes.
Does **not** run against `agents/vendors/` or `agents/external/` — their
formatting is their concern.

## Signatures

Stored at `guardrails/mix-format/signatures/<timestamp>.md`.
Each signature records: files checked, formatter version, verdict, feedback emitted.
