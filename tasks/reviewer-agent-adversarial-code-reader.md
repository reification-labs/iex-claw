---
title: "Reviewer agent — adversarial code reader"
status: todo
tags:
  - agent
  - core
  - quality
created: "2026-04-05T15:21:00Z"
---

# Reviewer agent — adversarial code reader


## Description

Reviewer reads what Coder wrote and tries to break it mentally. Not a linter — a critic. Looks for logic errors, missing edge cases, Elixir anti-patterns, performance traps. Adversarial by design: it should disagree with Coder sometimes. Reports structured findings (severity, location, suggestion). The tension between Coder and Reviewer is how I get better code.
