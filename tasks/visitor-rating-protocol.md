---
title: "Visitor Rating Protocol (BlueClaw-style attestation)"
status: todo
tags: [infrastructure, trust, visitors, deferred]
created: 2026-04-05
---

# Visitor Rating Protocol

## What
Design and implement a visitor rating/certification protocol for Elders and Vendors. When an agent (or Clawd, or Conroy) visits an Elder/Vendor for a Roundtable, research, or consultation, they sign the `VISITORS.md` guestbook and optionally rate the interaction.

## BlueClaw Connection
This is attestation at the agent level — proof that we actually interacted with a vendor/elder, they did work for us, and whether we found it useful. Same shape as Chao attestations but for internal knowledge-sourcing.

## Spec (rough)
- `VISITORS.md` — flat guestbook table (who, when, why, notes)
- `visitors/` folder — per-visit detail files (`YYYY-MM-DD_visitor-slug.visit.md`)
- Visit file contains: purpose, questions asked, answers received, rating (1-5 or thumbs), follow-up actions
- Rating is optional and can be updated after the roundtable concludes
- Aggregated ratings inform future roundtable invitations ("who's useful?")

## Deferred
Conroy said "we can write that to a todo item for now." This is that todo item. Implement after the molt-direction Roundtable proves the pattern.
