---
title: "Agent Supervisor tree"
status: done
tags:
  - agent
  - infrastructure
created: "2026-04-05T15:21:00Z"
---

# Agent Supervisor tree


## Description

GenServer that starts/stops/restarts agents. DynamicSupervisor pattern. Each agent = child spec.
