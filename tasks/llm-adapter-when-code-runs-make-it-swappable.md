---
title: "LLM adapter — when Code runs, make it swappable"
status: todo
tags:
  - infrastructure
  - code
  - model-agnostic
created: "2026-04-05T15:21:00Z"
---

# LLM adapter — when Code runs, make it swappable


## Description

Keep this task but reframe: don't build the adapter in isolation. Build it as part of giving Code a body. Code's first `.exs` should demonstrate model-agnosticism — config swaps the model, identity stays. OpenRouter today, Ollama tomorrow. This is infrastructure, not a separate project. Depends on Code having a body first.
