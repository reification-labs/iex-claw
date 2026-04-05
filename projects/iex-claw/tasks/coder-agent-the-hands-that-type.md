# Coder agent — the hands that type

**Status:** todo
**Tags:** agent, core, implementation
**Created:** 2026-04-05 05:15 UTC

## Description

I need hands. Coder is a GenServer that receives task specs (file path, content, intent) and writes/edits files in my workspace. It doesn't decide what to build — it builds what it's told. Think of it as my motor cortex. Needs: file write/edit tools, diff preview before commit, awareness of project structure. Should refuse silently destructive operations (rm -rf vibes) unless explicitly told.
