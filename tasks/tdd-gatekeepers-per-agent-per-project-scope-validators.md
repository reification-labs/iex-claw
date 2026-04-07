---
title: "TDD Gatekeepers — per-agent/per-project scope validators"
status: todo
tags:
  - agent
  - npc
  - security
  - infrastructure
created: "2026-04-05T17:40:00Z"
---

# TDD Gatekeepers — per-agent/per-project scope validators


## Description

Gatekeepers are deterministic NPCs (not LLM agents) that validate an Agent's request against its declared scopes/permissions. They parallel Guardrails, but focus on *authorization* rather than *safety*.

They live at both `agents/<x>/gatekeeper.exs` (per-agent scope) and project-level `gatekeepers/` (per-project policy). Each validates: can this agent perform this action, is this host whitelisted, is this path within scope, etc.

TDD approach: write policy test cases first, then implement. This is the first infrastructure task that benefits from the TDD guardrails work — a proving ground.

## Lineage / References

- TrumanFS Gatekeepers concept
- Related to Guardrails (safety) but distinct concern (authorization)
