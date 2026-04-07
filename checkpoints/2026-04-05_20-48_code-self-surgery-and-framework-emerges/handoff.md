---
date: 2026-04-05T20:48:00-04:00
project: iex-claw
checkpoint: 2026-04-05_20-48_code-self-surgery-and-framework-emerges
session_id: d71adaec-53fc-4230-9f7e-e84e24b5a084
---

# Checkpoint: Code Self-Surgery + The Framework Emerges

## Summary

Epic session. Started with a 4-step work order to extract tools and rewire agents, ended with Code (GLM-5 Turbo) planning and executing surgery on his own body using a Mode-constrained PlanExecute strategy. Along the way: 8-voice Roundtable decided unanimously against external framework adoption, the tick protocol got clock-in-meta, and we built Mode/Contract/Strategy primitives that make agent self-modification safe and bounded.

## What Was Accomplished (chronological)

### Phase 1: Complete the Substrate Molt (steps 1-3 of handoff work order)
- Extracted `IExClaw.Tools.Messages` + `IExClaw.Tools.AgentLogger` to `lib/` with 14 new tests
- Ticked Code (budget=1 each) to rewire both inline modules to thin delegators
- All 5 inline Tools.* in code.exs are now delegators to compiled lib/ modules
- Fixed `write_file` nil-boolean bug (`not nil` → `!= true`)
- Fixed `inbox_tick.exs` InboxDemo.go() unconditional execution (now respects IEXCLAW_SKIP_DEMO)

### Phase 2: Clock-in-Tick + Roundtable Scaffolding
- `tick/1` → `tick/2`: all Tickables receive `%{clock: iso_timestamp}` in meta
- Scaffolded 2 Elders (iexreact, pearl-demo) + 1 new Vendor (ash bundle) with `.gitignore`'d `src/` clones
- Stubbed `agents/project/` with SOUL/IDENTITY/PHILOSOPHY (no LLM body)
- VISITORS.md guestbook for all participants
- Visitor rating protocol deferred to task

### Phase 3: Molt-Direction Roundtable (8 voices, unanimous)
- Woke 4 beings in parallel (GLM-5 Turbo, ~35-43s each): Vendor Jido, Vendor Ash, Elder IExReAct, Elder PeARL-demo
- Ticked Code + Goal for their voices
- **Decision: Neither Jido nor Ash. Extract to lib/ and write own behaviours.**
- Both Vendors pitched against themselves ("not yet, here's the signal for when")
- Decision matrix: 4 lift to lib/, 3 stay DIRT, 1 defer

### Phase 4: The Framework Emerges (extraction)
- `IExClaw.ToolRegistry` — shared tool registry (as_openai_tools/2, execute/3)
- `IExClaw.LLMClient` — thin OpenAI-compatible HTTP adapter
- `IExClaw.Agent` — behaviour + helpers (load_soul_docs, agent_loop, append_message, extract_summary)
- `IExClaw.Tickable` + `IExClaw.Tick.Pump` — moved from .exs to lib/
- Added `{:req, "~> 0.5"}` to mix.exs deps
- 60 → 69 tests at this point

### Phase 5: PlanExecute Strategy + Mode-Constrained Surgery
- Built `IExClaw.Strategies.PlanExecute` — survey/execute/verify phase machine
- Built `IExClaw.Mode` — constrained tool sets per phase ("the phone in another room")
- Built `IExClaw.Contract` — lifecycle with restart-on-budget-exhaustion
- Built `IExClaw.Tools.SubmitPlan` — forced exit gate from survey mode
- Built `tick_refactor.exs` — PlanExecute-powered self-surgery harness
- Generated MAP files for Code's section map + lib/ module index
- **5 dry runs → learned Code's failure patterns → Mode constraint was the fix**
- **Code planned his own surgery** (3-step plan via submit_plan tool)
- **Code executed his own surgery** (3 edits, self-healed on string escape mismatch)
- code.exs: 20,475 → 19,790 bytes. 84 tests pass. credo clean.

## Status

- **Done:**
  - All 5 Tools.* in code.exs delegated to lib/
  - ToolRegistry in code.exs delegated to IExClaw.ToolRegistry (Code did this himself!)
  - Framework modules extracted to lib/ (ToolRegistry, LLMClient, Agent, Tickable, Pump)
  - Roundtable decided: extract, don't adopt external frameworks
  - PlanExecute + Mode + Contract primitives working

- **Next (the remaining rewire targets):**
  1. Rewire `agent_loop` + `call_llm` + `append_message` + `extract_summary` → IExClaw.Agent + IExClaw.LLMClient (Code can do this via tick_refactor with updated MAP)
  2. Rewire `load_soul_docs` → IExClaw.Agent.load_soul_docs
  3. Repeat 1+2 for Goal
  4. Build Project-as-real-agent on the shared substrate

## Key Files

### New lib/ modules (the framework)
- `lib/iex_claw/tool_registry.ex` — shared ToolRegistry
- `lib/iex_claw/llm_client.ex` — LLM adapter
- `lib/iex_claw/agent.ex` — Agent behaviour + helpers
- `lib/iex_claw/tickable.ex` — Tickable behaviour
- `lib/iex_claw/tick/pump.ex` — Tick pump
- `lib/iex_claw/mode.ex` — Mode-constrained tool sets
- `lib/iex_claw/contract.ex` — Supervisor↔Agent contract
- `lib/iex_claw/strategies/plan_execute.ex` — PlanExecute strategy
- `lib/iex_claw/tools/submit_plan.ex` — Survey exit gate
- `lib/iex_claw/tools/messages.ex` — DIRT bus messaging
- `lib/iex_claw/tools/agent_logger.ex` — Growth logger

### New agents/harnesses
- `agents/tick_refactor.exs` — PlanExecute-powered self-surgery harness
- `agents/project/` — SOUL/IDENTITY/PHILOSOPHY (stub, no LLM)
- `agents/elders/iexreact/` + `agents/elders/pearl-demo/` — Elder repos
- `agents/vendors/ash/` — Ash bundle vendor

### New MAP files
- `agents/map/maps/code-exs-sections.md` — Code's file section map with byte offsets
- `agents/map/maps/lib-iex-claw-modules.md` — lib/ module index with APIs

### Roundtable
- `roundtable/2026-04-05_molt-direction.conversation.md` — 8-voice framework decision
- `roundtable/voices/code-molt-direction.md` + `goal-molt-direction.md`

## Key Principles Discovered

- **"Make the change easy, then make the easy change"** — Kent Beck. Pre-generate MAPs, constrain tools via Mode, then let Code do the easy edits.
- **Mode = phone in another room.** Telling an agent "don't use X" doesn't work. Removing X from the registry does.
- **Contract = terms of engagement.** Supervisor and Agent agree to modes, budget, restart conditions.
- **"The framework emerges from the agents"** — Elder IExReAct. Don't design then build. Build until the framework is obvious.
- **"The clock lives in the tick"** — Conroy. Timestamp in meta, not discovered per-agent.
- **MAP as DIRT cache** — agents ask for directions instead of exploring. "Show me what's there first" meets "trust the map."

## Commits This Session (12)
- `c7cf149` — extract Messages + AgentLogger to lib/
- `db8693a` — rewire Tools.Messages delegation
- `(next)` — rewire Tools.AgentLogger delegation
- `(next)` — roundtable prep scaffolding + clock-in-tick
- `820327d` — roundtable: molt-direction (unanimous)
- `502a648` — the framework emerges (ToolRegistry, LLMClient, Agent, Tick to lib/)
- `(next)` — PlanExecute strategy
- `(next)` — tick_refactor harness + dry-run learning
- `(next)` — MAP files for Code's self-surgery
- `0cb120a` — Mode + Contract + SubmitPlan (Code plans his surgery)
- `6ca16a6` — 🦞 Code performs surgery on himself

## To Resume

```
Read this handoff. The next work order is:

1. Update the MAP (code-exs-sections.md) to reflect current state post-surgery
2. Run tick_refactor again for agent_loop/call_llm/etc → IExClaw.Agent + LLMClient
3. Run tick_refactor for load_soul_docs → IExClaw.Agent.load_soul_docs
4. Generate goal-exs-sections.md MAP, then tick_refactor Goal
5. Build Project-as-real-agent on the shared substrate

Reference: tick_refactor.exs is the self-surgery harness.
Mode + Contract enforce phase boundaries and restart safety.
84 tests, credo clean, dialyzer clean.
```
