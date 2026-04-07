---
title: "Web NPC — per-project fetch/cache/tmp store"
status: todo
tags:
  - npc
  - infrastructure
  - dirt
created: "2026-04-05T17:40:00Z"
---

# Web NPC — per-project fetch/cache/tmp store


## Description

TrumanFS lineage. A deterministic NPC per project that holds local fetches, caches, downloads, tmp files, and browsing history. Think "DIRT set of browser tabs for a project."

Lives alongside Postmaster as a bus neighbor. Gives agents a stable place to stash and retrieve web artifacts without each agent rolling its own fetch+cache logic.

## Lineage / References

- TrumanFS DIRT pattern
