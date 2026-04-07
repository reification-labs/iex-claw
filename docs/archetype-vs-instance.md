# Archetype vs. Instance vs. Agent vs. Single-Instance NPC

Not everything in the system gets a soul. Here's what does and why.

## Definitions

Four kinds of things exist in this architecture:

**Agent** — LLM-powered, alive, has SOUL + IDENTITY + PHILOSOPHY. Agents are first-class participants with wants, refusals, and relationships. Examples: `agents/code/SOUL.md`, Goal, Project.

**Archetype** — a template for a family of related NPCs. The archetype holds a SOUL.md that encodes the discipline *every* instance must honor. Concrete instances inherit shape from the archetype but don't get their own souls. Examples: Guardrail (`agents/guardrail/SOUL.md`), Gatekeeper (`agents/gatekeeper/SOUL.md`).

**Instance** — a concrete NPC born from an archetype. Has a spec file (e.g. `guardrails/mix-format.md`), not its own soul. Runtime is deterministic — dead in the function body, runtime-facing. The `mix-format` guardrail doesn't philosophize; it runs `System.cmd("mix", ["format", "--check-formatted"])` and reports pass or fail.

**Single-instance NPC** — a unique deterministic tool that doesn't belong to a family. No soul. Examples: MAP (`agents/map/README.md`), Web (`agents/web/README.md`).

## Why Archetypes Get Souls

The archetype's SOUL encodes *values* — the discipline that makes every instance recognizable as part of the family.

Guardrail's soul says: one check, one verdict, four flavors of pushback, never grow a second check organically. Gatekeeper's soul says: deny comes with a reason, silence is not permission, one authorization axis per gatekeeper.

These values are **author-facing**, not runtime-facing. When a human (or Clawd) creates a new guardrail instance — say `guardrails/dialyzer.md` — they read the archetype's SOUL to ensure the new spec fits the family. The SOUL is a contract for *authors*, not instructions for *execution*.

Instances inherit discipline through the spec file format (see below), not by loading SOUL.md at runtime. Nothing in the execution path reads the archetype's soul. The function body runs deterministically.

Changing an archetype's SOUL changes what counts as membership in the family. If Guardrail's SOUL dropped the "one check" rule, instances that check multiple things would suddenly be valid. The soul is the gate.

## Why Instances Don't Get Souls

Instances are concrete, not abstract. Their behavior *is* the function body — there's nothing to encode as values beyond "apply the archetype's discipline here."

An instance's spec file (`guardrails/mix-format.md`) is its contract. Its code (`mix format --check-formatted`) is its execution. What values would a soul add? The discipline already lives in the archetype, and the concrete behavior lives in the spec. A soul here would be commentary on a closed question.

## Why Single-Instance NPCs Don't Get Souls

No siblings means no family means no shared values to encode.

MAP is one cartographer. There's no MAP-with-a-different-personality. Web is one fetcher. There's no Web-that-caches-aggressively vs. Web-that-fetches-fresh. The NPC is the thing; the thing is the NPC.

If you find yourself wanting to give a single-instance NPC a soul, ask: would there be sibling instances with different specs but shared discipline? If yes, promote it to an archetype. If no, leave it soulless. Not everything needs inner life. Reliable machinery doesn't.

## Decision Tree: Should This Thing Get a SOUL?

```
Does it use an LLM?
├── Yes → Agent. Give it SOUL.
└── No → NPC.
    │
    Are there multiple instances in a family?
    ├── Yes → Archetype + instances. Archetype gets SOUL.
    └── No → Single-instance NPC. No SOUL.
```

## How Instances Inherit Discipline

The spec file format is the archetype's enforcement mechanism. Every guardrail instance, for example, follows the same shape:

```markdown
# <name> Guardrail
## Check
## Pass Criteria
## Addresses
## Notes
```

Fill in the template = carry the discipline forward. The format constrains what an instance *can* express, which is how the archetype's values survive without being loaded at runtime. A guardrail spec can't declare "I check two things" without it being visibly wrong against the one-check-per-guardrail format.

This is why archetype SOUL is author-facing: you read it *while authoring* a new instance. By the time the instance exists, the discipline is already baked into its structure.

## Cross-References

- `agents/guardrail/` — first archetype, "one check, one verdict"
- `agents/gatekeeper/` — second archetype, "deny with reason"
- `agents/map/` — single-instance NPC, filesystem cartographer
- `agents/web/` — single-instance NPC, cached web fetcher
- `agents/code/` — full agent, LLM-powered, has soul
- `docs/supervisor-as-primitive.md` — parallel structural doc on supervision

---

*Souls are for values. Functions are for execution. Don't confuse them.*
