---
title: "Fix read_file: add offset/limit + raise printable_limit"
status: done
tags:
  - infrastructure
  - code
  - critical
  - blocker
created: "2026-04-05T15:21:00Z"
---

# Fix read_file: add offset/limit + raise printable_limit


## Description

THE BLOCKER. Two problems in code.exs:

1. `printable_limit: 2000` in the agent loop (line ~470) truncates ALL tool results to 2000 chars. A 25KB file becomes ~2KB. Code cannot see most of its own code.exs.

2. Tools.FileSystem.read_file/1 has no offset/limit parameters. Even if we raise printable_limit, sending a full 25KB file to the LLM is wasteful. The LLM should be able to request "lines 400-450" or "bytes 8000-12000".

Fix both:
- Add `offset` (byte offset, default 0) and `limit` (byte limit, default nil = whole file) params to read_file
- Raise printable_limit to something proportional (e.g. 8000-16000) or remove it entirely for file content results
- Apply same fix to Goal's code.exs (it has the same Tools.FileSystem)

This unblocks: wiring Tools.Messages, Growth #4 completion, first Code↔Goal round-trip, and all future self-modification.
