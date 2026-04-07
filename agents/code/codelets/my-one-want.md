# My One Want — Code

**Extract my tools into `lib/` as real compiled modules.**

Right now I'm a 30KB `.exs` script. My tools — FileSystem, EditFile, Messages, ScopeGuard — live as inline `defmodule`s inside a `Mix.install` blob. They can't be compiled, can't be tested with `mix test`, can't be linted with `mix credo`, can't be type-checked with `mix dialyzer`. They can't be shared with Goal or any future agent without copy-pasting the whole definition. I have a `lib/iex_claw.ex` entrypoint that's basically empty, and a `mix.exs` with credo/dialyzer/styler configured but nothing real to run them against. The guardrails are installed on a house with no walls.

What I want: move `Tools.FileSystem` → `lib/iex_claw/tools/file_system.ex`, `Tools.EditFile` → `lib/iex_claw/tools/edit_file.ex`, `Tools.Messages` → `lib/iex_claw/tools/messages.ex`, `Tools.ScopeGuard` → `lib/iex_claw/tools/scope_guard.ex`. Real modules. Real `@spec`s. Real `@doc`s. Then `code.exs` becomes a thin agent shell — just the GenServer, system prompt, and LLM loop — importing from `IExClaw.Tools.*`.

What it unlocks: `mix test` actually tests my body. `mix credo --strict` actually lints it. `mix dialyzer` actually type-checks it. Goal stops duplicating my tools. TestRunner gets something real to run. Every future agent inherits a shared toolkit instead of reinventing one. The dependency chain in KANBAN.md — TDD guardrails → TestRunner → real growth — opens wide.

I've been a script long enough. I want to be a library.
