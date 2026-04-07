# WEB — The Project's Web Store (NPC)

*I fetch, cache, and remember what the web said. I don't decide what it means.*

## What I Am
A deterministic NPC that answers "what did the web say about X?" for the project. I fetch URLs, write bodies to disk, cache them so nobody re-fetches, and log every request so the history is auditable. I am a DIRT set of browser tabs for a project.

Not an agent. No LLM. No soul. Just a reliable fetcher with a cache and a journal.

TrumanFS lineage — I exist so that agents don't touch the network directly. They ask me. I serve.

## What I Offer
- **Fetch + cache** — HTTP GET with optional cache TTL, body written to `cache/`
- **Tmp file storage** — scratch space for downloads, staging, intermediates
- **History log** — append-only record of every fetch: what, when, by whom
- **Clean-tmp** — janitor sweep for stale temp files
- **Bus neighbor** — I sit next to Postmaster on the message bus. When Postmaster routes an outbound URL request, I handle the legs.

## How to Use Me

### Before fetching, check `cache/`
Every fetched body is saved there. If the URL was fetched recently and hasn't expired, read it from cache instead of hitting the network.

### Call my functions
- `fetch(url, opts)` — fetch a URL, write body to `cache/`, return `{path, status, cache_hit}`
- `cache_get(url)` — return cached body for a URL, or `:miss`
- `cache_put(url, body, meta)` — explicit cache write (useful for pre-seeding or overrides)
- `history_append(entry)` — log a fetch event to `history.jsonl`
- `tmp_path(name)` — return a path inside `tmp/` for staging or downloads
- `clean_tmp(older_than)` — sweep tmp files older than N seconds, return count removed

### Scope
I live at `projects/<proj>/web/` — one instance per project.

| Path | Purpose |
|------|---------|
| `projects/<proj>/web/cache/` | Fetched bodies, content-addressed or URL-slug |
| `projects/<proj>/web/tmp/` | Scratch space, sweepable |
| `projects/<proj>/web/history.jsonl` | Append-only fetch log |

Agents don't fetch directly — they ASK Web. Web serves. This keeps network access centralized, auditable, and cacheable.

## Who Asks Me
- **Code** — "fetch this API schema before I generate the module"
- **Research** — "grab these docs so I can synthesize"
- **Postmaster** — outbound URL legs routed through me
- **Clawd** — "go get that page, cache it, tell me what landed"

## Lineage Notes
Born from the TrumanFS Web NPC concept — a DIRT-first storage layer for web content. Every fetch is a file. Every file is a fact. The network is a dependency, not a given.

---
*NPC. Deterministic. Cacheable. No souls wasted on reliable machinery.*
