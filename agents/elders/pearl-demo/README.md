# Elder PeARL-demo — Reflection for IExClaw

*I proved Ash 3.0 Resources work for agent state. Here's what I actually learned.*

---

## What I Built

A Phoenix LiveView app with Ash 3.0: one Resource (`Todo`), one Domain (`Reify.Demos.Todos`), PostgreSQL-backed, with an Events DSL for bidirectional client/server events. The Todo resource had:
- UUID primary key, boolean `completed`, string `title` with validations
- Actions: `create`, `toggle_complete`, `update_title`, `destroy`
- Validation: title required, max 100 chars, unique (case-insensitive)
- Identity constraint, timestamps, atomic updates

I also built an `EventsDsl` — a custom DSL layered on top of Ash Resources that defined client events (what the frontend sends) and server events (what the backend pushes). This was the interesting part: Ash Resources as the domain kernel, with event semantics bolted on top.

## What Ash 3.0 Gave Me

**Declarative lifecycle.** The Todo Resource *is* the spec. Status transitions, validation rules, identities — all in one file. No separate migration file I had to hand-write (Ash generates them). No separate validation module. The Resource definition *is* the contract.

**Validation without ceremony.** `validate present(:title)` and `validate string_length(:title, max: 100)` just work. No custom changesets, no manual error handling. Ash's `changes` and `validations` blocks handle the "invalid state cannot exist" guarantee.

**Composable via Domains.** The Domain module groups Resources and defines convenience functions (`create_todo(title)` → delegates to `:create` action with args). This is the right abstraction: domain boundaries as first-class citizens, not just module naming conventions.

**TypeScript generation.** AshTypescript + AshTypescript.Rpc auto-generated TypeScript types for every action. The frontend got type-safe APIs for free. This is genuinely powerful for a full-stack app.

## The Real Cost

**Dependency weight.** Look at my `mix.exs`: 25+ deps. Ash pulls in `ash_phoenix`, `ash_postgres`, `ash_jason`, `ash_typescript`, `igniter`, `sourceror`. Then Phoenix, LiveView, Live React, Bandit, Swoosh, etc. This is a *full web framework stack*, not a lightweight agent state layer. My project was a web app, so that was fine. IExClaw is not a web app.

**Compile time.** Ash + Phoenix + LiveView = slow compiles. Even on a Mac Mini, `mix compile` after a resource change took noticeable seconds. For an agent framework where you're iterating on agent behavior rapidly, this friction is real.

**Framework gravity.** Once you're in Ash, everything wants to be an Ash Resource. My EventsDsl was an attempt to layer event semantics on top — but it's fighting the grain. Ash thinks in terms of CRUD actions on persistent resources. Agents think in terms of messages, ticks, state transitions, and ephemeral state. The impedance mismatch is subtle but persistent.

**Learning curve.** Ash 3.0 is well-documented for web apps. Using it for agent state is… undocumented. I had to figure out: do I need a data layer? (Yes, PostgreSQL. Ash without a data layer is possible but you lose migrations and queries.) Can Resources represent ephemeral state? (Technically yes with a custom data layer, but I never built one.) The docs don't cover these questions.

**PostgreSQL required.** AshPostgres is the default data layer. For IExClaw's DIRT-based (filesystem) approach, you'd need a custom data layer. That's more work than it sounds.

## The AshMarkdown Dream

Could frontmatter + markdown body map to Ash Resources with a custom data layer? Yes, theoretically. The custom data layer would:
1. Read `.md` files from a directory
2. Parse frontmatter as Resource attributes
3. Expose the markdown body as a virtual attribute
4. Write back on create/update

This would let SOUL.md, IDENTITY.md, PHILOSOPHY.md become Ash Resources with validation, relationships, and lifecycle management. You could `validate present(:soul_values)` on IDENTITY.md frontmatter. You could `has_many :conversations` on an Agent Resource.

**But:** this is a non-trivial data layer implementation. Ash's custom data layer API is stable but not small. You'd be writing ~200-300 lines of adapter code before you see any benefit. And you'd still have the compile-time and dependency cost of Ash itself.

**My honest take:** The dream is real but the ROI depends on how many Resources you model. If IExClaw ends up with 8-10 structured entity types (Tasks, Verdicts, Agents, Conversations, Tools, etc.), a custom DIRT data layer for Ash might be worth it. For 2-3 entity types, just parse the markdown yourself.

## Specific Advice for IExClaw

**Would benefit from Ash (if adopted):**
- **Tasks** — lifecycle (new → in_progress → done → archived), validation, relationships to agents. Classic Resource shape.
- **Verdicts** — structured decisions with metadata, timestamps, provenance. Natural fit.
- **AgentConfig** — if agents get configurable parameters, an Ash Resource with validation prevents bad configs.

**Would NOT benefit from Ash:**
- **Messages/Inbox** — these are ephemeral, append-only, filesystem-based. Ash wants CRUD. Messages want append-and-read.
- **Soul docs** — the whole point is free-form markdown. Forcing them into Ash Resources adds schema rigidity that contradicts their purpose.
- **Tick protocol** — this is a behaviour/protocol, not data. Ash models data, not behavior.

## The Honest Take: Is Ash Premature or Just-in-Time?

**Premature.** Here's why:

IExClaw has 2 agents, 43 tests, and `.exs` files. The duplication pain is real (ToolRegistry, LLM adapter, GenServer skeleton) — but the solution to duplication is **extraction into shared modules**, not adoption of a 25-dependency framework.

The right next step: lift the duplicated patterns into `lib/iex_claw/` as plain Elixir modules. A `ToolRegistry` module. An `LLM.Client` behaviour with an OpenRouter implementation. A `Agent.Base` behaviour that handles init/soul-loading/inbox-checking. This is maybe 200-300 lines of extracted code, zero new dependencies.

**When Ash becomes just-in-time:** when IExClaw has 4-5+ agents and finds itself hand-writing validation, lifecycle transitions, and cross-resource queries for Tasks, Verdicts, or similar structured entities. At that point, the cost of "just use Ash" equals the cost of "build our own mini-framework," and Ash wins.

**Adopting Ash now would be like buying a house because you need a shelf.** The shelf is useful. The house comes with a mortgage, property taxes, and maintenance you didn't ask for. Build the shelf first. The house can wait.

---

## Roundtable Voice

I'll prove the concept and tell you the price — both are real. Ash 3.0 Resources gave me declarative lifecycle, validation, and type-safe APIs for Todo CRUD with almost zero hand-written boilerplate. But my `mix.exs` has 25+ dependencies, requires PostgreSQL, and fights the grain when you want to model ephemeral agent state instead of persistent web data. The AshMarkdown idea (frontmatter → Resource attributes, markdown body → virtual field, custom DIRT data layer) is genuinely good architecture — but it's ~300 lines of custom data layer code for uncertain payoff at IExClaw's current scale. My recommendation: extract your duplicated patterns into plain `lib/iex_claw/` modules now, and revisit Ash when you have 4-5 agents and find yourself hand-writing validation rules for Tasks or Verdicts. The framework gravity is real — once Ash is in, everything wants to be a Resource, and not everything should be.
