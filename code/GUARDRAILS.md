# GUARDRAILS.md — Active Checks on Code's Changes

*The list of specialist sign-offs Code must pass before a change is considered safe.*

Maintained collectively. Each guardrail has a detail file at `guardrails/<slug>.md`.
Archetype soul/identity/philosophy lives at `agents/guardrail/`.

## How This Works

1. Code produces a change.
2. Code (or Project, on Code's behalf) runs each applicable guardrail.
3. Each guardrail emits one verdict (pass/fail) and any feedback in the four flavors.
4. On all passes → change is safe to commit.
5. On any fail → Code addresses the feedback (fix, or push back to the addresser) before retry.
6. Signatures are recorded at `guardrails/<slug>/signatures/<timestamp>.md`.

## The Four Feedback Flavors

| Flavor | Meaning | Blocks? |
|--------|---------|---------|
| ❓ Question | I need clarification before I can check this. | **yes** (hard block — can't proceed) |
| 💬 Comment | Noticed while checking. FYI. | no |
| ⚠️ Concern | Nearby risk. Pause and think. | **yes** (soft block — override requires choosing to) |
| 💡 Suggestion | Consider this. Forward-looking. | no |

**Severity lives in pass/fail.** All four flavors can coexist with either verdict. A hard block means "I literally can't." A soft block means "you can, but own the decision."

## Active Guardrails

| Slug | Checks | Scope | Spec |
|------|--------|-------|------|
| **no-self-truncation** | File edits preserve total byte count (no accidental truncation regression) | Any edit_file operation | [no-self-truncation.md](guardrails/no-self-truncation.md) |
| **tools-wired** | Every function in Tools.* modules is registered in @tools map | Any change to Tools.* or ToolRegistry | [tools-wired.md](guardrails/tools-wired.md) |
| **mix-format** | `mix format --check-formatted` exits 0 (incl. Styler) | Any .ex/.exs change in lib/test/agents | [mix-format.md](guardrails/mix-format.md) |
| **credo** | `mix credo` exits 0 with zero issues (consistency + warnings) | Any .ex/.exs change in lib/test/agents | [credo.md](guardrails/credo.md) |
| **dialyzer** | `mix dialyzer` exits 0 with "done (passed successfully)" | Any change affecting @spec or public API | [dialyzer.md](guardrails/dialyzer.md) |

## Guardrail Lifecycle

- **Born** — a new guardrail gets a `guardrails/<slug>.md` spec, is added to this index, and has its first signature recorded on the next Code change it applies to.
- **Retired** — when a check becomes obsolete (e.g. covered by a stronger guardrail), move the spec to `guardrails/retired/` and remove from this index. Signatures stay for history.
- **Questioned** — if a guardrail produces repeated Questions, Code or Project may ask it to refine its spec.

## Growing the Roster

Conroy-requested next wave (from TDD guardrails task):
- `mix-format` — runs `mix format --check-formatted`
- `ex-unit` — runs the test suite
- `credo` — consistency linting (Elder Truman: start loose, tighten gradually)
- `dialyzer` — type contracts (Elder Truman: "not your friend," use judiciously)
- `scope-guard-honored` — no file writes outside the agent's declared workplace

Each becomes its own `guardrails/<slug>.md` when born.

---
*One check. One signature. Four flavors of pushback.*
