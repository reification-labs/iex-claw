---
title: "TDD guardrails: mix project, tests, formatter, credo, dialyxir"
status: todo
tags:
  - infrastructure
  - testing
  - guardrails
  - conroy-requested
  - hot
created: "2026-04-05T15:21:00Z"
---

# TDD guardrails: mix project, tests, formatter, credo, dialyxir


## Description

Conroy-requested. Right now Code flies blind: no mix project, no test runner, no mix format, no credo/dialyxir, no CI. When Code self-modifies and breaks itself (see 2026-04-05 read_file regression), there is nothing to catch it except Clawd noticing at runtime.

What to build:
1. mix.exs at projects/iex-claw/ root (we already installed Elixir)
2. Migrate agents/*/*.exs to lib/ once tests prove the molt
3. test/ directory with ExUnit tests for every tool module (read_file, edit_file, scope_guard, messages)
4. .formatter.exs + run mix format in CI
5. credo.exs (consistency first, per Elder Truman: do not start strict)
6. dialyxir (plt_add_apps, stable plt_file, per Elder Truman: dialyzer is not your friend)
7. Pre-commit hook or GitHub Action that runs mix test + mix format --check-formatted

Reference test already exists: projects/iex-claw/test/read_file_slicing_test.exs (standalone ExUnit, 10 tests, green). Use as the template/migration seed.

This is THE lesson from 2026-04-05: Code needs TestRunner for self-healing feedback, but TestRunner needs a mix project to run. Bootstrap the mix project first.
