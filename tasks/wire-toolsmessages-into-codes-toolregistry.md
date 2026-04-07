---
title: "Wire Tools.Messages into Code's ToolRegistry"
status: done
tags:
  - agent
  - code
  - implementation
  - growth-4
created: "2026-04-05T15:21:00Z"
---

# Wire Tools.Messages into Code's ToolRegistry


## Description

Growth #4 completion. Code built Tools.Messages (read_inbox, read_message, send_message) but never registered them in the ToolRegistry @tools map. The LLM is blind to all three message functions.

Goal already delivered the exact fix (verdict: rewrite, msg-2026-04-05-115542-215.msg.json). Add three entries to Code's ToolRegistry matching the existing pattern:
- read_inbox → Tools.Messages.read_inbox/0
- read_message → Tools.Messages.read_message/1  
- send_message → Tools.Messages.send_message/4

Blocked by: read_file fix (Code can't see its own ToolRegistry to edit it).

Once done: Code can read Goal's verdict from its inbox, apply fixes, and send acks. First full round-trip becomes possible.
