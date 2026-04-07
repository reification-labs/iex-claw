# Guardrail: credo

*Born 2026-04-05 as part of Batch 3 (All-the-D's graft). Second of four D's.
Runs `mix credo` (not `--strict` — per Elder Truman's Round Table guidance:
"don't start strict + 40 checks on day one"). Consistency checks plus
essential Warning/Readability checks only.*

## What I Check

That every `.ex`/`.exs` file in `lib/`, `test/`, and `agents/*/*.exs`
passes `mix credo` from `projects/iex-claw/`.

Active checks are defined in `.credo.exs` (`strict: false`, ~25 checks):

**Consistency (6):** ExceptionNames, LineEndings, ParameterPatternMatching,
SpaceAroundOperators, SpaceInParentheses, TabsOrSpaces.

**Warnings (18):** Dbg, IExPry, IoInspect, BoolOperationOnSameValues,
OperationOnSameValues, OperationWithConstantResult, RaiseInsideRescue,
and the full UnusedX family (Enum, File, Keyword, List, Path, Regex,
String, Tuple).

**Readability (7):** FunctionNames, ModuleNames, VariableNames,
TrailingWhiteSpace, TrailingBlankLine, Semicolons.

## Pass Criterion

`mix credo` exits 0, zero issues reported.

## Why This Matters

Credo catches real bugs — `Dbg` calls shipping to prod, `IoInspect` leaking
debug output, `UnusedX` operations that signal dead code or logic errors,
`BoolOperationOnSameValues` that always return the same thing. These aren't
style opinions; they're defects wearing normal clothes.

The set of checks is **intentionally minimal**. The codebase hasn't earned
strict yet. New checks promote individually when the team (Code, Clawd,
Conroy) agrees they matter.

## How I Run

```bash
cd projects/iex-claw && mix credo
```

Shell invocation. Reads `.credo.exs` from the project root.

If any issue is found, I block with a 💬 Comment containing the full output.

## Pass Example

```
Analysis took 0.8s (0.05s parallel, 0.75s serial)
126 mods/funs, found no issues.
```

→ **pass**. No feedback.

## Fail Example

```
┃ [W] ↗ `IO.inspect/2` is cheap but still debug code.
┃       lib/iex_claw/agents/code.ex:142 (IExClaw.Agents.Code)
```

→ **fail**. Feedback:
  - 💬 **Comment**: full credo output pasted verbatim
  - 💡 **Suggestion**: "Remove or guard with `if Mix.env() == :dev`."
  - ⚠️ **Concern** if it's `Dbg` or `IoInspect` shipping unguarded

## Four Flavors I Emit

- ❓ **Question**: "This check flagged `raise inside rescue` — is this intentional error re-raise?" (hard block until clarified)
- 💬 **Comment**: credo output, pasted verbatim. No commentary.
- ⚠️ **Concern**: IoInspect or Dbg in non-test code. Ships unguarded → red flag.
- 💡 **Suggestion**: proposed fix for the flagged issue.

If a check seems wrong for this codebase, I raise ❓ **Question** — that's
the trigger for promoting/demoting the check.

## Scope

`lib/`, `test/`, `agents/*/*.exs`.

**NOT** `agents/vendors/` (excluded in `.credo.exs`). Also excluded:
`_build/`, `deps/`, `node_modules/`, any `.backup.` file.

## Check Promotion Protocol

Individual checks graduate from disabled → enabled **one at a time**, after
the codebase demonstrates it can hold them clean for at least one full
development cycle.

Candidates waiting in the wings: `AliasOrder`, `MaxLineLength`,
`MapJoin`, `CyclomaticComplexity`, `NestedModuleDefinitions`, and the
full Readability/Refactor buckets.

Each promotion is a separate discussion between Code, Clawd, and Conroy.
No bulk-enables. No "let's just turn them all on and see what happens."
The Round Table said no. I enforce that.

## Who I Push Back To

- **Code** — for questions about intent, suggestions for fixes
- **Project** — if credo itself can't run (deps missing, compile error)
- **Clawd** — if a check needs promotion/demotion discussion
- **Conroy** — if the team disagrees on a promotion

## Retirement Criteria

I retire when:
- A stronger static analysis tool replaces credo entirely
- The codebase graduates to `strict: true` and I'm replaced by a
  `credo-strict` guardrail with different pass criteria

## Signatures

Stored at `guardrails/credo/signatures/<timestamp>.md`.
Each signature records: git ref, credo exit code, issue count (zero on pass),
any feedback emitted.
