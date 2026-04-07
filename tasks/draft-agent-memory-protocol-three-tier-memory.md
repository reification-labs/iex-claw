---
title: "Draft Agent Memory Protocol — three-tier MEMORY.md/memories/"
status: todo
tags:
  - docs
  - architecture
  - memory
  - conroy-requested
created: "2026-04-05T17:40:00Z"
---

# Draft Agent Memory Protocol — three-tier MEMORY.md/memories/


## Description

Document the recursive per-agent memory pattern. Each agent gets its own MEMORY.md + memories/ directory, same fractal structure as the workspace root.

Three tiers: (1) short-term useful → whole file pulled inline into MEMORY.md, (2) medium-term useful → referenced by path, requires explicit read, (3) archival → lives in timestamped files like `memories/20260405T1329_that-one-time-at-band-camp.memory.md`.

A Memory agent (future) serves as librarian, helping agents find relevant memories about the project, Conroy, or Clawd.

Output: `docs/agent-memory-protocol.md`.

## Lineage / References

- Conroy-requested
- Workspace AGENTS.md memory section as reference pattern
