---
title: "Generalize Supervisor concept — primitive, not role"
status: todo
tags:
  - architecture
  - design
  - correction
created: "2026-04-05T17:40:00Z"
---

# Generalize Supervisor concept — primitive, not role


## Description

Correction to Symphony's task-biased supervisor model. In IExClaw, Supervisors are a general-purpose *primitive*. Any Agent can host Supervisors, supervising anything: child agents, Guardrails, Gatekeepers, codelets, heartbeats.

IExClaw supervises its projects' AGENTS.md; Code supervises its own Guardrails; turtles all the way down. Document this clearly before building the Supervisor agent so we don't accidentally inherit Symphony's task-centric bias.

## Lineage / References

- See `agents/vendors/symphony/IDENTITY.md` bookmarks section for Symphony's model
