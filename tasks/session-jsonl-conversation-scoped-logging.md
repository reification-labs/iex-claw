---
title: "Session JSONL — conversation-scoped logging"
status: todo
tags:
  - infrastructure
  - observability
created: "2026-04-05T17:40:00Z"
---

# Session JSONL — conversation-scoped logging


## Description

Current `logs/{agent}.*.log` files are per-agent history. We also need conversation-scoped JSONL logs — append-only, one file per session/conversation, capturing the full message exchange across participating agents.

Separate from per-agent traces. Unifies with claw-code's session logging pattern. Keep both: agent histories AND conversation histories.

## Lineage / References

- claw-code session logging pattern
