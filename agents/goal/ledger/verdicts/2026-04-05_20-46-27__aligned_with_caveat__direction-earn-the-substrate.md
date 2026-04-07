# Verdict: aligned_with_caveat

**Subject:** direction-earn-the-substrate
**Rendered:** 2026-04-05T20:46:27.067394Z
**Agent:** Goal

---

## Direction Note: Earn the Substrate

**One direction. Three-to-six sentences. Here it is.**

Wrap the working `.exs` agents into a proper `mix` project with tests, formatter, credo, and dialyxir — *before* adding a third agent. The North Star says "not a toy, not a demo, a workable substrate." Right now we have two standalone scripts that proved the pattern. That's a prototype, not a substrate. The molting threshold is reached: we've repeated the pattern twice (Code, Goal), the round-trip works, the bus is real. The next repetition without a test harness is recklessness — Code already broke itself once today (banner regression) and we only caught it by hand. A mix project with TDD guardrails unlocks TestRunner (Code's feedback loop, serving subgoal #4: symbiotic economy), gives every future agent a runner to prove itself against, and earns the abstraction that subgoal #2 demands ("standalone first, framework later" — we've stood alone, now we earn the framework). Conroy already requested this. The dependency chain is open. This isn't exploration — it's the next right thing.

**Serves:** Subgoal #2 (standalone first, framework later) and #4 (symbiotic economy).
**Unlocks:** TestRunner agent, reliable iteration on existing agents, the right to call this a substrate instead of a prototype.
**Risk if skipped:** Every new agent is a house of cards. Every regression is a surprise. We stay in demo territory.

---
*The North Star doesn't move. I move the map.*
