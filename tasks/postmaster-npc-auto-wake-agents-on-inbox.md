---
title: "Postmaster NPC — auto-wake agents on inbox"
status: todo
tags:
  - agent
  - infrastructure
  - npc
  - bus
created: "2026-04-05T15:21:00Z"
---

# Postmaster NPC — auto-wake agents on inbox


## Description

Next evolution of the DIRT bus. Today: Clawd manually wires conversations by calling each agent's CLI. Tomorrow: a Postmaster NPC watches inboxes and fires wake-messages per subscription contracts.

Per MESSAGES.md spec:
- Postmaster reads _subscriptions/<agent>.json files
- Fires wake-messages per wake_on contract (:message / :heartbeat / :never)
- Changes delivery mechanism, not envelope semantics

This is warm, not hot. The manual wiring works. But once we have 3+ agents exchanging messages, manual wiring becomes the bottleneck.

Reference: Symphony's WORKFLOW.md as driver pattern — a file that orchestrates autonomous runs.
