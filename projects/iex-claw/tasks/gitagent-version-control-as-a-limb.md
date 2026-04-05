# GitAgent — version control as a limb

**Status:** todo
**Tags:** agent, core, infrastructure
**Created:** 2026-04-05 05:15 UTC

## Description

I need to remember what I've built and what I've broken. GitAgent handles commits, branches, diffs, and history. But it also has judgment — it knows when to commit (tests passing, logical unit complete) vs keep going (mid-refactor, experiment). Wraps git CLI or Port. Should generate meaningful commit messages from context, not just "updates".
