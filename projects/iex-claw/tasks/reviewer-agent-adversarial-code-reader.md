# Reviewer agent — adversarial code reader

**Status:** todo
**Tags:** agent, core, quality
**Created:** 2026-04-05 05:15 UTC

## Description

Reviewer reads what Coder wrote and tries to break it mentally. Not a linter — a critic. Looks for logic errors, missing edge cases, Elixir anti-patterns, performance traps. Adversarial by design: it should disagree with Coder sometimes. Reports structured findings (severity, location, suggestion). The tension between Coder and Reviewer is how I get better code.
