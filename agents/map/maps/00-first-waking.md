# MAP — First Waking

**Generated:** 2026-04-05 09:30 UTC
**Asked by:** household (first wake)

**First map:** `project-tree.md`. Full recursive walk of `projects/iex-claw/`, depth 3. Reason: every other question I get assumes I know the shape of the place. I don't yet. This is the zero-knowledge map everything else builds on.

**What I need before answering "where should this go?":** Three things. One: what already exists (the tree map fixes this). Two: what layer the thing is—DIRT, LOAM, or LOOM. Three: whether there's an existing convention I should follow (naming patterns, file-per-concept vs grouped, flat vs nested). I can suggest, but I shouldn't invent conventions the household hasn't agreed to.

**Expected layer shape as the project grows:**
- **DIRT:** `agents/` (SOUL.md, IDENTITY.md per agent), `tasks/` (one file per task, slug names), `proposals/`, raw session logs. Things that hurt if lost.
- **LOAM:** `maps/` (my output), any generated indexes, compiled digests. Regeneratable from DIRT. No human should need to edit these.
- **LOOM:** Reports, dashboards, anything built for browsing. Thin layer. Probably lives elsewhere or gets generated on demand rather than stored.

**Question for Code:** What's your current rule for where new functions land—grow in place until it hurts, or split early? I need to know whether to expect monolithic files or already-distributed modules when I map your territory.

---
Maps directory doesn't exist yet. I'll create it on first save.
