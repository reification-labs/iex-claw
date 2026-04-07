---
title: "First full Code↔Goal round-trip"
status: done
tags:
  - agent
  - infrastructure
  - milestone
  - bus
created: "2026-04-05T15:21:00Z"
---

# First full Code↔Goal round-trip


## Description

Proof of life for the DIRT bus. The full cycle:

1. Goal sends Code a verdict (already happened: msg-2026-04-05-115542-215)
2. Code reads its inbox (needs Tools.Messages wired)
3. Code reads the message, understands the verdict
4. Code applies the fix (needs read_file offset/limit)
5. Code sends Goal an ack or "done" message
6. Goal reads Code's response and confirms

This is the minimal viable inter-agent communication loop. If this works, the bus is real. Everything else (Postmaster, more agents, supervised runs) builds on this.

Blocked by: read_file fix + Tools.Messages wiring.
