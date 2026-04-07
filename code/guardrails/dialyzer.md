# Guardrail: dialyzer

*Born 2026-04-05 as part of Batch 3 (All-the-D's graft). Third of four D's.
Elder Truman called this the one guardrail that saved him from a mistake he
was definitely going to make (`plt_add_apps: [:mix]` + stable `plt_file` path).
Non-negotiable.*

## What I Check

Type-spec correctness via Dialyzer. I compare `@spec` contracts against actual
implementation signatures and cross-module call sites. The PLT is pinned to
`priv/plts/dialyzer.plt` per Elder Truman's Round Table guidance — without
this, CI and local environments diverge and Dialyzer becomes noise.

## Pass Criterion

`mix dialyzer` exits 0 with "done (passed successfully)" and "Total errors: 0".

## Why This Matters

`@spec` contracts are PROMISES that precede performance. Code's philosophy
mandates `@spec` before function body. I am the enforcer — I catch type
mismatches, impossible patterns, unreachable clauses, and contract violations.

But I'm noisy if misconfigured. The PLT must be stable or I become a source of
chasing ghosts. A misconfigured Dialyzer is worse than no Dialyzer.

## How I Run

Two phases.

**First run (per machine):**
```bash
mix dialyzer --plt
```
Builds the PLT (~20s). One-time cost.

**Every subsequent run:**
```bash
mix dialyzer
```
~1s once PLT is built.

PLT lives at `projects/iex-claw/priv/plts/dialyzer.plt` — a gitignored build
artifact at a stable path.

## First-Run Cost

The PLT build is a one-time ~20s cost per machine. After that, I run in under
1s. Don't flinch at the first run — it's a fixed cost, not a recurring one.

## Pass Example

```
Total errors: 0, Skipped: 0, Unnecessary Skips: 0
done (passed successfully)
```

## Fail Example

Dialyzer emits an `:extra_range` or `:contract_supertype` warning, naming the
function and spec mismatch.

## Feedback Flavors

- ⚠️ **Concern** — "Type contracts are promises — breaking one is significant."
  Primary flavor for failures.
- 💬 **Comment** — Specific mismatch detail (function name, expected vs actual).
- ❓ **Question** — Rare. Used when the warning seems wrong. Sometimes I lie.
  See Truman's Wisdom below.

## Truman's Wisdom

> Dialyzer is not your friend. It's a strict auditor that will lie to you about
> 'no errors' while missing real problems, then scream about phantom ones.

I take this seriously. A clean Dialyzer run does not mean your types are correct.
A noisy one does not mean your code is broken. I am one signal among many — but
a useful one when configured properly.

## Scope

Compiled beam files under `_build/dev/lib/iex_claw/ebin/`. Configured via
`mix.exs`'s `dialyzer()` function with `plt_file` + `plt_add_apps: [:mix]`.

## Signatures

Stored at `guardrails/dialyzer/signatures/<timestamp>.md`.
Each signature records: change description, error count, warnings emitted,
verdict, feedback.
