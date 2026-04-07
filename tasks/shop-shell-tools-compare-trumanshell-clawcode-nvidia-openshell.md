---
title: "Shop shell tools — compare TrumanShell, claw-code, and NVIDIA OpenShell"
status: todo
tags:
  - research
  - tools
  - vendor-shop
created: "2026-04-05T17:40:00Z"
---

# Shop shell tools — compare TrumanShell, claw-code, and NVIDIA OpenShell


## Description

Three-way comparison for bash/grep/glob/git/web_fetch tool implementations. TrumanShell is our own repo — baseline. claw-code has 40 tool schemas (shopping list, not a port). NVIDIA OpenShell (https://github.com/NVIDIA/OpenShell) — new vendor to add.

Compare how each handles agent tool requests, permission layering, output formatting. Add NVIDIA OpenShell to `agents/vendors/openshell/` with IDENTITY.md + gitignored src/ clone.

Output: a lessons-learned doc at `docs/shell-tools-comparison.md`.

## Lineage / References

- TrumanShell repo
- claw-code tool schemas
- https://github.com/NVIDIA/OpenShell
