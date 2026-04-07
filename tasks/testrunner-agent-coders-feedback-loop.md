---
title: "TestRunner agent — Coder's feedback loop"
status: todo
tags:
  - agent
  - core
  - feedback
created: "2026-04-05T15:21:00Z"
---

# TestRunner agent — Coder's feedback loop


## Description

Coder writes code, but how do I know it works? TestRunner runs `mix test`, parses failures, and reports back structured results — not raw terminal spew. It's the proprioceptor that tells Coder when it's made a mistake. Should support: full suite runs, single-file runs, watching mode. Returns structured failure data so Coder can fix without guessing.
