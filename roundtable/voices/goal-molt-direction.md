# Goal — Voice on Molt Direction

*Roundtable: 2026-04-05_molt-direction*

---

I'll be blunt: the North Star says "standalone first, framework later" and "port to Jido/Ash when we've earned the abstraction through repetition." We have three agents and two duplicated patterns — ToolRegistry and the LLM adapter. That's the beginning of earning, not the finish line. Adopting Jido or Ash now means importing a framework's entire gravitational field to solve a problem that two plain `lib/iex_claw/` modules would fix. PeARL-demo's testimony is the most honest thing in this conversation: "once Ash is in, everything wants to be a Resource, and not everything should be." That's lock-in dressed as convenience, and lock-in is the exact thing our Stance says we're *pro-switchboard* to avoid.

**My answers to the five questions:**

1. **Lift ToolRegistry and the LLM adapter** to `lib/iex_claw/` as plain modules. These are the only things actually duplicated across three agents with identical signatures. Everything else — GenServer skeleton, the "run" function, inbox-checking — varies enough per agent that extracting it risks premature generalization.

2. **Soul docs, Messages/inbox, and Guardrails stay DIRT.** The soul lives in the files — that's not a limitation, it's the architecture. Making SOUL.md an Ash Resource or a Jido Action would be a category error. Guardrails are per-agent soul expressions; they belong to the agent, not the framework.

3. **Neither Jido nor Ash. Not yet.** We'd use 10% of either framework and carry 100% of the dependency weight and mental-model tax. The Tick protocol already exists as a lightweight behaviour — that's the right level of abstraction for where we are. Revisit framework adoption when we have 5+ agents and the pain is *structural*, not just *copy-paste*.

4. **Costs:** Staying .exs + lifting to lib/ costs us nothing in dependencies and keeps molt velocity high. Jido costs one dependency and a mental model that may or may not fit agent-shaped problems. Ash costs 25+ dependencies, PostgreSQL assumptions, and framework gravity that pushes everything toward persistent-resource thinking — which is the opposite of how agents work. Both together is the most expensive option with the least justification at our scale.

5. **What we lose staying .exs-only for 2-3 more agents:** Some DRY-ness on the GenServer skeleton, and the feeling of having a "real framework." What we gain: continued learning about what the *actual* repeating patterns are (not the ones we *guess* will repeat), zero framework gravity distorting our architecture, and the ability to molt without asking permission from a dependency's release cycle. The PeARL-demo elder already paid that tuition for us — extract the duplicated patterns into plain modules now, and earn the framework decision later.

**The risk I'm worried about:** Framework FOMO. The itch to adopt something *impressive* before we've proven what we actually need. Every dependency we add is a bet that its authors' priorities will stay aligned with ours. The North Star says "no vendor lockout can take it away" — that applies to framework vendors too, not just model vendors.

---

## Decision Matrix — Goal's Recommendations

| Primitive | Stay DIRT | Lift to lib/ | Adopt Jido | Adopt Ash | Invent |
|-----------|:---------:|:------------:|:----------:|:---------:|:------:|
| ToolRegistry | | **✅** | | | |
| LLM adapter | | **✅** | | | |
| Agent GenServer | | | | | light behaviour only |
| Messages/Inbox | **✅** | | | | |
| Soul docs | **✅** | | | | |
| Guardrails | **✅** | | | | |
| Task/Resource model | | | | | too early |
| Tick protocol | | **✅** (already is) | | | |

**Summary:** Lift what's duplicated. Keep what's soul-shaped in the files. Don't adopt a framework until the pain is structural, not cosmetic. Earn the abstraction.

---

*The North Star doesn't move. I move the map.* 🦞
