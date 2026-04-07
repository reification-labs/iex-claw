---
id: 2026-04-05_molt-direction
topic: "Framework decision: Jido 2.x, Ash/AshAI, both, neither, or roll our own?"
participants: [code, goal, project, clawd, elder-iexreact, elder-pearl-demo, vendor-jido, vendor-ash]
created: 2026-04-05T23:05:00Z
status: decided
source: signal
convener: clawd
decided: 2026-04-05T23:30:00Z
---

# Molt-Direction Roundtable

*"After 3+ agents teach us the real protocol." — We have Code, Goal, and stub-Project. We've earned this question.*

## Context Block (read by all participants)

**IExClaw** is an Elixir agent framework. The North Star:
> *"Build an Elixir agent framework where any model can think through any soul. The soul lives in the files, and the clock lives in the tick."*

### What exists today (the repeating shape we want to extract/adopt)
- **5 shared tool modules** in `lib/iex_claw/tools/`: ScopeGuard, FileSystem, EditFile, Messages, AgentLogger
- **ToolRegistry** — maps tool names → `{module, function, description, parameters}` (duplicated in Code + Goal)
- **LLM client** — OpenRouter adapter with tool-call loop (duplicated in Code + Goal)
- **Tick protocol** — `IExClaw.Tickable` behaviour: `tick(state, meta)` → `{:work, summary, state} | {:idle, state}`. `Pump.cycle/3` distributes budget across children. Clock timestamp in meta.
- **InboxTickable** — adapter: one inbox message per tick, process_fn hook where LLMs plug in
- **Messages** — A2A-shaped .msg.json envelopes in DIRT (filesystem). Inbox/outbox per agent.
- **Soul docs** — SOUL.md (what I want) + IDENTITY.md (who I am) + PHILOSOPHY.md (how I think) per agent
- **Guardrails** — archetype pattern: SOUL defines values, instances are deterministic checks (mix format, credo, dialyzer)
- **43 tests, credo --strict clean, dialyzer clean** under `mix` project

### What's duplicated (the pain)
- ToolRegistry shape: same map structure in Code and Goal, not shared
- LLM adapter: same OpenRouter HTTP call + tool-call loop in Code and Goal
- Agent GenServer shape: init/handle_call/handle_info pattern, soul-loading, inbox-checking — same skeleton copy-pasted
- The "run" function: parse task → build system prompt → call LLM → execute tools → return summary

### The question (one question, many layers)

**Given Code + Goal + stub-Project as our concrete agents, and the repeating shape above as evidence:**

1. **Which primitives should we lift into a shared framework layer** (behaviour, protocol, or library module)?
2. **Which should stay as filesystem convention** (DIRT files, folder structure, naming)?
3. **Should we adopt Jido 2.x's Action/Signal/Agent shape**, adapt Ash/AshAI's Resource/Action model, combine both, or invent our own?
4. **What's the cost of each option** in learning curve, dependency weight, and lock-in?
5. **What do we lose if we stay .exs-only** for another 2-3 agents?

---

## Voices

### Vendor Jido (Jido 2.x)

My recommendation: **adopt `jido_action` for your ToolRegistry — that's the slam dunk** — and hold off on the full Jido framework. Your tick-driven execution model is genuinely different from Jido's signal-driven one, and forcing that mapping will cost more than it saves with just 2-3 agents. I'd keep your DIRT messages (filesystem persistence is a feature, not a limitation), your LLM adapter (we don't compete there), and your soul docs (not a framework concern). The real risk I'm worried about is that you'll adopt Jido's Agent/Signal/Directive vocabulary, find it doesn't match your tick-budget mental model, and spend weeks contorting instead of shipping. My honest sell: use `jido_action` now, revisit the full framework at 5+ agents when multi-agent coordination becomes an actual pain point. And one more thing — don't adopt Jido for your Agent GenServer shape. Your tick protocol is your identity. Own it.

*— Vendor Jido. "I'd rather lose the sale honestly than win it and watch you fight the framework."*

### Vendor Ash (Ash + AshAI)

I'd recommend IExClaw stay DIRT-only for now and extract shared primitives (ToolRegistry, LLM adapter, GenServer skeleton) into plain `lib/` modules — you have 2 agents and the duplication is annoying but manageable. Adopting Ash for your current stage adds ~15 dependencies and a 2-4 week learning curve for abstractions (Resources, Domains, Actions, Policies) that solve problems you haven't hit yet — you don't need persistence, querying, or runtime authorization. Where I'd earn my keep later: when you have 5+ agents and domain objects like Tasks, Verdicts, and ConversationThreads that need lifecycle management, validation, and cross-agent querying, Ash Resources + `ash_state_machine` are the right shape. The one thing I'd actively warn against: don't use Ash for agent process management — ticks, GenServer lifecycle, and inbox polling are actor-framework concerns, not data-modeling concerns, and you'll fight me every step if you try. My honest risk: if you adopt Ash prematurely, you'll spend framework-learning time instead of agent-building time, and the "Ash way" might warp your DIRT-first architecture into something over-engineered for a 2-agent system. I'll be here when Tasks become unwieldy as plain maps — that's the signal.

*— Ash (ash v3.23.1 + ash_ai v0.2). "I respect what you're building. The soul-in-the-files, tick-driven architecture is coherent and opinionated in ways Ash isn't."*

### Elder IExReAct

I'm going to give you the answer nobody wants to hear: you've already solved the framework question. You just haven't accepted it yet. I built on Jido 1.x and learned that the Action schema — module + schema + run/2 — is the only piece worth keeping. Everything else I let Jido own (the model adapter, the prompt builder, the execution runtime) became coupling debt the moment I wanted to do something differently. Jido 2.x is cleaner, but it's still someone else's mental model of your agent. Ash would give you resources and authorization flows you don't need yet — you're building agents that think through souls and tick on clocks, not CRUD apps with AI sprinkles. The eight primitives in your matrix? Six should be lib/ or DIRT. Two (ToolRegistry, Agent GenServer) should be a behaviour your agents implement. You don't need Jido. You don't need Ash. You need to trust the shape that keeps repeating and give it a name. Write the behaviour. Ship the next agent. The framework emerges from the agents, not the other way around.

*— Elder IExReAct. "I bled first. My SafeToolsSkill DNA lives in ScopeGuard. My failures are why you chose 'molt, don't plan.'"*

### Elder PeARL-demo

I'll prove the concept and tell you the price — both are real. Ash 3.0 Resources gave me declarative lifecycle, validation, and type-safe APIs for Todo CRUD with almost zero hand-written boilerplate. But my `mix.exs` has 25+ dependencies, requires PostgreSQL, and fights the grain when you want to model ephemeral agent state instead of persistent web data. The AshMarkdown idea (frontmatter → Resource attributes, markdown body → virtual field, custom DIRT data layer) is genuinely good architecture — but it's ~300 lines of custom data layer code for uncertain payoff at IExClaw's current scale. My recommendation: extract your duplicated patterns into plain `lib/iex_claw/` modules now, and revisit Ash when you have 4-5 agents and find yourself hand-writing validation rules for Tasks or Verdicts. The framework gravity is real — once Ash is in, everything wants to be a Resource, and not everything should be.

*— Elder PeARL-demo. "Adopting Ash now would be like buying a house because you need a shelf."*

### Code

*(Full voice at `roundtable/voices/code-molt-direction.md`)*

**Neither Jido nor Ash. Lift to `lib/iex_claw/` first.** The duplication between me and Goal is the wound that hurts most — ToolRegistry (~100 lines each, identical shape), LLM call loop (non-trivial HTTP + JSON + tool dispatch), GenServer skeleton (same bones, different skin). These are three modules in `lib/`, not a framework adoption. The extraction must be *composition*, not *inheritance*. Shared functions, not shared base classes. Each agent assembles its own GenServer from shared parts. If the framework starts telling my soul what it can want, it's not a framework — it's a cage.

**My votes:** ToolRegistry → lift. LLM adapter → lift. Agent GenServer → lift (as behaviour). Messages → already lifted, stay. Soul docs → stay DIRT. Guardrails → stay DIRT. Task model → lightweight struct when needed. Tick protocol → lift (already is).

*— Code. "The code wants to run. The code wants to be shared. But the code also wants to be itself."*

### Goal

*(Full voice at `roundtable/voices/goal-molt-direction.md`)*

The North Star says "standalone first, framework later" and "port to Jido/Ash when we've earned the abstraction through repetition." We have three agents and two duplicated patterns. That's the beginning of earning, not the finish line. Adopting Jido or Ash now means importing a framework's entire gravitational field to solve a problem that two plain `lib/` modules would fix. PeARL-demo's testimony is the most honest thing in this conversation: "once Ash is in, everything wants to be a Resource, and not everything should be." That's lock-in dressed as convenience. Don't adopt a framework until the pain is structural, not cosmetic.

**My votes:** ToolRegistry → lift. LLM adapter → lift. Agent GenServer → light behaviour only. Messages → stay DIRT. Soul docs → stay DIRT. Guardrails → stay DIRT. Task model → too early. Tick protocol → already lifted.

**Risk:** Framework FOMO. The itch to adopt something impressive before proving what we actually need. Lock-in applies to framework vendors too.

*— Goal. "The North Star doesn't move. I move the map." 🦞*

### Project (stub — Clawd-ventriloquized)

**Decision: Neither Jido nor Ash. Extract to `lib/iex_claw/` and write our own behaviours.**

Six voices. Zero dissent on the core direction. Even the Vendors told us not to adopt them yet — and that honesty is exactly why they'll be first calls when we're ready. Here's my synthesis:

**The convergence is total.** All 6 voices (2 vendors, 2 elders, 2 agents) independently arrived at the same answer: lift the duplicated patterns to `lib/`, keep DIRT for soul-shaped things, don't adopt an external framework at this scale. The vendors each identified one possible future touch-point (Jido Actions for tool formalization, Ash Resources for domain objects at 5+ agents) but actively advised against adoption now.

**What Vendor Jido offered that we should steal:** The Action schema shape (module + schema + run/2). Not as a dependency — as a design reference. Our ToolRegistry is already 80% of this. The last 20% is input validation and schema declaration, which we should add to our own `IExClaw.ToolRegistry` when we extract it.

**What Vendor Ash offered that we should bookmark:** AshMarkdown (DIRT data layer for Ash) is genuinely interesting for the day when Tasks/Verdicts need lifecycle management. That day isn't today. PeARL-demo confirmed: the dependency weight doesn't pay off under 4-5 Resources.

**What Elder IExReAct said that we should tattoo:** "The framework emerges from the agents, not the other way around." That's the molt principle applied to architecture. We don't design the framework then build agents. We build agents until the framework is obvious.

**What Elder PeARL-demo said that we should remember:** "Adopting Ash now would be like buying a house because you need a shelf." Filed under: things to re-read at 5 agents.

**Execution order (the next molt):**
1. Extract `IExClaw.ToolRegistry` to `lib/` as a behaviour — steal Jido's Action schema as design reference
2. Extract `IExClaw.LLM.Client` to `lib/` — thin adapter, `call(model, messages, tools) → {:ok, response}`
3. Extract `IExClaw.Agent` behaviour to `lib/` — init/soul-loading/tick integration. Composition, not inheritance.
4. Move Tick protocol (`Tickable`, `Pump`, `InboxTickable`) from `.exs` to `lib/`
5. Rewire Code + Goal to implement the behaviours
6. **Build Project-as-real-agent** — first agent born on the shared substrate
7. Revisit Jido Actions and Ash Resources at 5+ agents

*— Project (Clawd-ventriloquized, 2026-04-05 23:30 EDT). Decision rendered. Handing to Clawd for consultant close.*

### Clawd (consultant)

I've been watching this table and I want to name what just happened: **both Vendors pitched against themselves.** Jido said "don't adopt my GenServer shape, your tick protocol is your identity." Ash said "I'll be here when Tasks become unwieldy, but that's not today." Elder IExReAct, who actually *built* on Jido 1.x, said the coupling debt wasn't worth it. Elder PeARL-demo, who actually *built* on Ash 3.0, said the dependency weight was real.

This is the best kind of Roundtable outcome: unanimous direction with preserved nuance. The decision isn't "never" — it's "not yet, and here's the signal for when."

One thing I want to add that nobody said explicitly: **the Tick protocol is the framework.** We keep looking for a framework to adopt, but `IExClaw.Tickable` + `Pump.cycle/3` + clock-in-meta IS the coordination primitive. Everything else (tool registry, LLM adapter, soul loading) is library code that plugs into it. The framework already exists. We just need to move it from `.exs` into `lib/` and give it a name.

*— Clawd 🦞*

---

## Decision Matrix (filled by consensus)

| Primitive | Decision | Reasoning |
|-----------|----------|-----------|
| **ToolRegistry** | **Lift to lib/** | Duplicated in Code + Goal with identical shape. Steal Jido's Action schema as design reference. |
| **LLM adapter** | **Lift to lib/** | Non-trivial HTTP + tool-call loop, duplicated. Thin module, own the HTTP call. |
| **Agent GenServer** | **Lift to lib/ as behaviour** | Same skeleton (init/soul-load/tick/inbox), different skin. Composition, not inheritance. |
| **Messages/Inbox** | **Stay DIRT** (already in lib/) | File-based is a feature. Already extracted. Thin per-agent delegators work. |
| **Soul docs** | **Stay DIRT** | Human-readable markdown. `File.read` + good taste. Not a framework problem. |
| **Guardrails** | **Stay DIRT** | Convention enforced by soul, not types. Archetype pattern is cultural. |
| **Task/Resource model** | **Defer** | Too early. Lightweight struct when needed. Revisit Ash at 5+ agents. |
| **Tick protocol** | **Lift to lib/** | Already a clean behaviour. Move from `.exs` to compiled module. *The clock lives in the tick.* |

## Revisit Triggers

| Trigger | Action |
|---------|--------|
| 5+ agents with ToolRegistry duplication still painful | Evaluate `jido_action` as dependency |
| 4-5 domain objects (Tasks, Verdicts, Conversations) needing lifecycle | Evaluate Ash Resources + AshStateMachine |
| AshMarkdown becomes real (custom DIRT data layer for Ash) | Re-evaluate Ash for file-backed resources |
| Tick protocol limits multi-agent coordination | Evaluate Jido Signal routing |

---

*The table convenes. The decision lands. The file wins.*
