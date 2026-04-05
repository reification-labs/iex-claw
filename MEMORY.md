# MEMORY.md — IExClaw Project Memory

*Lean index. Daily logs in `memories/`. Deep context in checkpoints.*

## What I Am
An Elixir agent framework where any model can think through any soul. The soul lives in the files, and the clock lives in the tick. 🦞

## North Star
> *"Build an Elixir agent framework where any model can think through any soul."*

Ratified 2026-04-05. Pro-switchboard, not anti-anyone.

<<<<<<< HEAD
## Architecture (current, Apr 5)
=======
## Active Projects (Apr 5)
- **IExClaw** — Elixir agent framework. 4 agents live (MemoryPruner, TodoList, Project, AgentLogger). All `.exs`, standalone, composable. GLM-5 Turbo workhorse. 12 open tasks. `projects/iex-claw/`. Port to Jido 2.2.0 + Ash later.
- **Reification Labs launch** — PTO Apr 1-14, signups by Apr 15. LinkedIn draft ready.
- **VHAI Newsletter** — Issue #1 "The Pickpocket Problem" drafted.
- **XClaw Games** — warcraftlogs for AI coding. Fresh concept.
- **Anthropic lockout** — `claude-cli/*` works for now. Sub-agents → OpenRouter. Z.AI GLM Coding Plan as backup.
>>>>>>> 79d2b29 (daily: Apr 5 session — IExClaw baby crabs, USER.md refresh, agent logging)

### Agents
- **Code** — LLM agent (GLM-5 Turbo). Builder. 20KB .exs, partially rewired to lib/.
- **Goal** — LLM agent (GLM-5 Turbo). Conscience. Verdict system + ledger.
- **Project** — Stub only (SOUL/IDENTITY/PHILOSOPHY). No LLM body yet. Next to be built.
- **MAP** — NPC cartographer. Generates + caches DIRT maps.

### lib/iex_claw/ (the emerging framework)
| Module | Role |
|--------|------|
| `ToolRegistry` | Shared tool registry (as_openai_tools, execute) |
| `LLMClient` | Thin OpenAI-compatible HTTP adapter |
| `Agent` | Behaviour + helpers (soul loading, agent loop, message append) |
| `Tickable` | Tick behaviour (tick/2 with clock meta) |
| `Tick.Pump` | Budget-bounded cycle pump |
| `Mode` | Constrained tool sets per phase |
| `Contract` | Supervisor↔Agent lifecycle |
| `Strategies.PlanExecute` | Survey/execute/verify phase machine |
| `Tools.SubmitPlan` | Forced exit gate from survey mode |
| `Tools.Messages` | DIRT bus messaging |
| `Tools.AgentLogger` | Per-agent growth log |
| `Tools.FileSystem` | Scope-guarded file ops |
| `Tools.EditFile` | Atomic multi-edit |
| `Tools.ScopeGuard` | Path boundary enforcement |

### Key Primitives
- **Tick** — permission, not instruction. Budget-bounded. Clock in meta.
- **Mode** — constrained tool sets. "The phone in another room."
- **Contract** — terms of engagement. Budget exhaustion → restart from Known-Good.
- **DIRT** — filesystem as database. Soul docs, messages, maps.
- **MAP** — DIRT-cached file maps. Agents ask for directions, not explore.

## Key Decisions
- **Roundtable 2026-04-05**: Neither Jido nor Ash. Extract to lib/, write own behaviours. Revisit at 5+ agents.
- **Tool extraction pattern**: parametric modules in lib/ + thin delegators per-agent
- **PlanExecute + Mode**: agents can plan and execute their own refactors safely

## Key Principles
- "The framework emerges from the agents" — Elder IExReAct
- "Make the change easy, then make the easy change" — Kent Beck
- "Haz lo que debes" — do what you must
- "Molt, don't plan" — messy .exs now, framework after repetition
- "The soul lives in the files, not the weights" 🦞

## Tests
84 tests, 0 failures. credo --strict clean. dialyzer clean.

## Open Work
- [ ] Rewire Code's agent_loop/call_llm → IExClaw.Agent + LLMClient
- [ ] Rewire Code's load_soul_docs → IExClaw.Agent.load_soul_docs
- [ ] Same rewire for Goal
- [ ] Build Project-as-real-agent on shared substrate
- [ ] Postmaster NPC (auto-wake agents on inbox)
- [ ] Visitor rating protocol (BlueClaw attestation)

## Checkpoints
- `2026-04-05_18-14` — tick protocol + tools molt (pre-evening session)
- `2026-04-05_20-48` — Code self-surgery + framework emerges
