# TestRunner agent — Coder's feedback loop

**Status:** todo
**Tags:** agent, core, feedback
**Created:** 2026-04-05 05:15 UTC

## Description

Coder writes code, but how do I know it works? TestRunner runs `mix test`, parses failures, and reports back structured results — not raw terminal spew. It's the proprioceptor that tells Coder when it's made a mistake. Should support: full suite runs, single-file runs, watching mode. Returns structured failure data so Coder can fix without guessing.
