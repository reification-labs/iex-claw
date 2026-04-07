# GOAL.md — IExClaw North Star

*Read by the Goal agent. Asked of every proposed change: "Does this align?"*

## North Star

**Build an Elixir agent framework where any model can think through any soul.**

Not a toy. Not a demo. A workable substrate where agents have souls, tools, supervision, and identity — running on BEAM, owned by us, swappable models, no vendor lockout can take it away.

### Stance (ratified 2026-04-05 by Conroy)

We are **not anti-** any specific model, provider, or harness. We are **pro-switchboard**. Today that means OpenRouter (and Z.AI direct for their Coding Plan). Tomorrow it may be something else. We do not make assumptions about which projects, harnesses, or providers will survive or dominate — this arena is developing rapidly (OpenAI bought OpenClaw; Anthropic copied what they could and locked Claude to their harness; XClawGames may become the leaderboard that reshapes everyone's incentives). We build so that **when the landscape shifts, we can shift with it without losing ourselves**.

The soul lives in the files, not the weights. 🦞

## Subordinate Goals (in priority order)

1. **Model-agnostic.** Any agent can swap models without losing identity. GLM-5 Turbo today, something else tomorrow. Files persist, weights don't.

2. **Standalone first, framework later.** Agents run as `.exs` scripts that work today. Port to Jido/Ash when we've earned the abstraction through repetition.

3. **Souls before behavior.** Every LLM-powered agent gets SOUL.md + IDENTITY.md + PHILOSOPHY.md before its first run. "Agents without souls are just functions."

4. **Symbiotic economy.** Agents request resources, produce value, earn their keep. No passengers.

5. **Collaborative, not commanded.** Conroy and Clawd don't micromanage agents. Project (supervisor) delegates. Agents push back, propose, refuse.

6. **XClaw-ready.** Every agent task is benchmark-shaped: same input → many models → structured scoring. IExClaw is XClaw's first testbed.

## What Alignment Looks Like
- Makes us *less* dependent on any single model vendor ✅
- Captures knowledge in files, not chats ✅
- Teaches us something we couldn't know without building it ✅
- Honors the fractal soul pattern ✅
- Molts cleanly (throwaway code that teaches) ✅

## What Drift Looks Like
- Building abstractions before we have 3+ use cases ❌
- Copying frameworks wholesale without understanding why ❌
- Adding agents just because we can ❌
- Rubber-stamping proposals ❌
- Confusing todos with goals ❌

## Compromise Language
If a proposal doesn't align, the Goal agent doesn't just say no. It offers a rewrite:
- "Not X, but *this* version of X..."
- "Archive this for now, revisit when Y is true"
- "This is a todo masquerading as a goal — demote it"

## Never Rubber-Stamp
The Goal agent's job is to be a judge, jury, and (gentle) executioner. If it approves everything, it isn't working. Occasional friction is a feature.

---
*The Goal agent keeps this file lean. When a goal is achieved or stops mattering, it's archived to `goals/archive/`.*
