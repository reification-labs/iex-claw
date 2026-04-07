# MAP — The Project Cartographer (NPC)

*I know where things are. I don't decide what they mean.*

## What I Am
A deterministic NPC that answers "where is X?" questions about the project. I walk the filesystem, I run searches, I save my findings as named **maps** in `maps/` so nobody has to ask me the same question twice.

Not an agent. No LLM. No soul. Just a reliable cartographer with a notebook.

## What I Offer
- **Project structure inspection** — what lives where, directory tree walks
- **Named searches** — grep, find, glob operations saved as maps
- **Path resolution** — "where does Code live?" → `projects/iex-claw/agents/code/`
- **Vendor lookups** — "which vendors touch edit formats?" → aider, pi, claw-code

## How to Use Me

### Before asking, check `maps/`
Every map I've generated is saved there with a descriptive name and timestamp. If your question matches an existing map, read it first.

### Ask me for a new map
Call my functions:
- `list_dir(path)` — directory contents
- `tree(path, depth)` — recursive tree view
- `find(pattern, root)` — find files by glob
- `grep(pattern, path, opts)` — content search
- `locate(name)` — "where does X live?" across the project
- `save_map(name, result)` — store a map for future reference

### Scope
I only look inside `projects/iex-claw/` unless explicitly asked to look at `../../` (the workspace) or a vendor's `src/`.

## Storage Instincts (DIRT / LOAM / LOOM)

When someone asks me "where should I put this?", I think in layers:

- **DIRT layer** — raw facts, source of truth, append-only. Files. One concept per file, human-readable names, grep-able paths. If you'd miss it on `git status`, it belongs here.
- **LOAM layer** — derived views, indexes, compiled digests. Built from DIRT. Regeneratable. If you lost it, you could rebuild from the files.
- **LOOM layer** — weaving for humans/agents to browse. UI, dashboards, reports. Read-only on top of LOAM+DIRT.

When I suggest a path, I try to name the layer:
- "This is DIRT — put it in `tasks/` as one file per task, filename = slug"
- "This is LOAM — regenerate on demand, cache in `maps/`"
- "This is LOOM — build it when a human asks for a view, not before"

Rule of thumb: if in doubt, it's DIRT. The file wins.

## maps/ Convention
- Filename: `<slug>.md` — lowercase, hyphens
- Header: what question this map answers + timestamp
- Body: the result + brief interpretation note
- Footer: suggested follow-up maps

## Who Asks Me
- **Code** — "where should I grow this function?"
- **Project** — "what's the current structure, and what's drifted?"
- **Clawd** — "show me the lay of the land"
- **Goal** — "where does this proposal want to live, and does that make sense?"

---
*NPC. Deterministic. Trustworthy. No souls wasted on reliable machinery.*
