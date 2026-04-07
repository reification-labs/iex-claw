---
title: "Extract shared tool modules from Code and Goal"
status: todo
tags:
  - infrastructure
  - refactor
  - dedup
created: "2026-04-05T15:21:00Z"
---

# Extract shared tool modules from Code and Goal


## Description

Both code.exs and goal.exs duplicate: Tools.FileSystem, Tools.EditFile, Tools.ScopeGuard, Tools.AgentLogger, ToolRegistry. This is technical debt that will compound with every new agent.

Extract into shared modules under a common location (e.g. agents/shared/ or src/tools/). Both agents Mix.install or require the shared code.

Not urgent — works fine duplicated for now. But before we build a 3rd agent (Reader, Supervisor, etc.), this should be done. Molt pattern: extract when we have 3+ copies, not before.

Reference: Symphony's pattern of supervised runs with shared worker code.
