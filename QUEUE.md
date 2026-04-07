# QUEUE.md — IExClaw Heartbeat Work Queue

*The cursor for autonomous coding work. Owned by Clawd for now; will transfer to Project agent once Supervisor + Postmaster exist.*

**Protocol:**
- Heartbeat reads QUEUE, picks the first `status: ready` item, spawns GLM-5 Turbo, commits on success, marks `done`, stops.
- One item per heartbeat. No chaining.
- Failure → leave cursor, note error, escalate on next poll.
- Any item may be re-ordered or paused by editing `status` / `priority`.

**Model:** `openrouter/z-ai/glm-5-turbo` unless noted.
**Committer:** Clawd, on success only. Push to `origin/main`.

---

## 🎯 Active Queue

### 1. Clone NVIDIA OpenShell + scaffold vendor
- **status:** done (ef07b8b+1)
- **output:** `agents/vendors/openshell/IDENTITY.md` + gitignored `src/` clone
- **prompt:** "Clone https://github.com/NVIDIA/OpenShell into /Users/clawd/workspace/projects/iex-claw/agents/vendors/openshell/src/ (shallow clone). Ensure src/ is gitignored via parent .gitignore pattern (check agents/vendors/.gitignore — follow existing convention). Write IDENTITY.md matching the format of sibling vendors (see agents/vendors/symphony/IDENTITY.md for structure): Name, Origin, Language, Vibe, Who I Am, What I'm Good At, What to Ask Me, Where My Guts Are, Lineage Notes. Focus: agent tool requests, permission layering, shell-tool patterns. Infer content from the repo README + top-level structure. Keep it concise — match existing vendor vibe."

### 2. Draft `docs/agent-memory-protocol.md`
- **status:** done
- **output:** new doc, three-tier memory spec
- **prompt:** "Write /Users/clawd/workspace/projects/iex-claw/docs/agent-memory-protocol.md (create docs/ if missing). Specify the three-tier per-agent memory pattern: (1) short-term useful — whole file pulled inline into the agent's MEMORY.md; (2) medium-term useful — referenced by path, requires explicit read; (3) archival — timestamped files like `memories/20260405T1329_slug.memory.md`. Each agent gets its own MEMORY.md + memories/ directory, recursive fractal of the workspace root pattern. Describe: naming convention (ISO8601 + kebab slug + .memory.md), promotion/demotion between tiers, a future Memory NPC as librarian, filesystem-first (DIRT) storage. Tone: spec doc, ~150-250 lines, matches existing docs/ style if any exist (check first). Reference the related task: tasks/draft-agent-memory-protocol-three-tier-memory.md."

### 3. Draft `docs/supervisor-as-primitive.md`
- **status:** done
- **output:** architecture doc, Symphony correction
- **prompt:** "Write /Users/clawd/workspace/projects/iex-claw/docs/supervisor-as-primitive.md. Document why Supervisors are a general-purpose primitive in IExClaw, not a task-specific role. Core thesis: Symphony and similar coding-agent harnesses use one supervisor per implementation run. IExClaw is a general-purpose agent harness (bias toward growth+action, not tasks). Therefore any Agent can host Supervisors supervising anything — child agents, Guardrails, Gatekeepers, codelets, heartbeats. Include: (1) the correction vs Symphony, (2) nesting example (IExClaw supervises projects' AGENTS.md → projects supervise agents → Code supervises its own Guardrails → turtles down), (3) OTP mapping (Task.Supervisor + Process.monitor as the underlying primitive), (4) what Supervisors do NOT do (they don't decide WHAT to run — that's the Agent's job). Cross-reference agents/vendors/symphony/IDENTITY.md Patterns-to-Borrow section and task tasks/generalize-supervisor-concept-primitive-not-role.md. ~150-250 lines."

### 4. Draft `docs/shell-tools-comparison.md` (skeleton)
- **status:** done
- **output:** comparison skeleton, not yet populated
- **prompt:** "Write /Users/clawd/workspace/projects/iex-claw/docs/shell-tools-comparison.md as a SKELETON for a three-way comparison of shell-tool implementations: TrumanShell (our own, ~/workspace/truman-shell if present), claw-code (agents/vendors/claw-code/src/), NVIDIA OpenShell (agents/vendors/openshell/src/ — may have just been cloned). Frame the document with sections: Goal, Dimensions (tool set, permission model, output formatting, streaming, error handling, agent integration pattern), per-tool tables (bash, grep, glob, git, web_fetch — rows to fill in), and a Lessons/Decisions section at the end. Put clear TODO markers where content must come from reading the actual vendor repos. Do NOT read the repos yet — this is scaffolding for a later fill-in pass. Reference task tasks/shop-shell-tools-compare-trumanshell-clawcode-nvidia-openshell.md."

### 5. Lock #5 scope (YAML frontmatter migration)
- **status:** done
- **output:** Clawd writes a scope-lock note into this QUEUE.md item + a spec stub at tasks/adopt-yaml-frontmatter-for-all-task-files.md
- **prompt:** "Read /Users/clawd/workspace/projects/iex-claw/tasks/adopt-yaml-frontmatter-for-all-task-files.md and the existing format of task files (sample 3-4 files from tasks/). Draft a concrete YAML frontmatter schema: required fields (title, status, tags, created), optional fields (updated, priority, blocked_by, references, lineage). Decide: keep existing '**Status:** todo' lines or remove once frontmatter has them (remove — don't dupe). Append the locked-in schema to the existing task file as a new section '## Schema (locked 2026-04-05)'. Also create a tiny migration script spec (not code) at the end — what the migrator must do per file. Do NOT migrate any files yet — just lock the scope."

### 6. Back-migrate existing task files to YAML frontmatter
- **status:** done
- **output:** all tasks/*.md rewritten with frontmatter; KANBAN/TASKS unchanged
- **prompt:** "Using the schema locked in tasks/adopt-yaml-frontmatter-for-all-task-files.md, rewrite every file in /Users/clawd/workspace/projects/iex-claw/tasks/ to add a YAML frontmatter block. Remove the now-duplicated '**Status:**' / '**Tags:**' / '**Created:**' lines from the body. Preserve all other content. Report: count of files touched, any files that failed to parse, any anomalies. Do NOT touch TASKS.md or KANBAN.md — only tasks/*.md."

### 7. Scaffold Gatekeeper NPC skeleton
- **status:** done (as archetype, not NPC — matches Guardrail pattern)
- **output:** `agents/gatekeeper/` with SOUL/IDENTITY/PHILOSOPHY + stub .exs
- **prompt:** "Scaffold /Users/clawd/workspace/projects/iex-claw/agents/gatekeeper/ matching the structure of sibling NPCs (check agents/map/ for reference — it's the closest NPC example). Create: README.md, IDENTITY.md (deterministic NPC, per-agent AND per-project scope validator, sibling to Guardrails but focused on authorization not safety, lineage from TrumanFS Gatekeepers), PHILOSOPHY.md (decision frame: can this agent perform this action? is this host allowlisted? is this path within declared scope?), and a stub gatekeeper.exs with module skeleton (no policy logic yet — just the shape: check_action/3, check_host/2, check_path/2, plus @spec contracts). No SOUL.md (NPCs don't get souls — see agents/map/ and IExClaw IDENTITY.md taxonomy). Keep it tight, ~same size as agents/map/."

### 8. Scaffold Web NPC skeleton
- **status:** done
- **output:** `agents/web/` with IDENTITY + stub .exs
- **prompt:** "Scaffold /Users/clawd/workspace/projects/iex-claw/agents/web/ as an NPC (no SOUL.md). Match agents/map/ structure. IDENTITY.md: per-project fetch/cache/tmp/history store, TrumanFS lineage, 'DIRT set of browser tabs for a project,' bus neighbor to Postmaster. PHILOSOPHY.md: filesystem-first storage, caches live at projects/<proj>/web/{cache,tmp,history}/, agents don't fetch directly — they ask Web NPC. Stub web.exs with functions: fetch/2, cache_get/1, cache_put/2, history_append/1, clean_tmp/0. @spec contracts required. No implementation bodies beyond minimal return types. ~same size as agents/map/."

---

---

## 🎯 Batch 2 (brunch round, .exs-leaning)

### 15. Pin `docs/archetype-vs-instance.md`
- **status:** done
- **output:** philosophy doc
- **prompt:** "Write /Users/clawd/workspace/projects/iex-claw/docs/archetype-vs-instance.md (~100-150 lines). Thesis: archetypes keep souls because they embody VALUES (alive in the pattern, author-facing at instance creation time). Instances execute deterministically (dead in the function body, runtime-facing). Single-instance NPCs (MAP, Web) don't need souls — no multiple instances means no framework-level values to encode. Examples: Guardrail archetype has SOUL ('one check, one verdict'); the `mix-format` guardrail instance is a System.cmd call. Gatekeeper archetype has SOUL ('deny with reason'); the `path-scope` instance is a Path.starts_with?/2 check. Include: (1) definitions (archetype, instance, NPC, agent), (2) when to use which, (3) how instances inherit discipline from archetype SOUL (through spec file format, not runtime loading), (4) decision tree: 'should this thing get a SOUL?'. Cross-reference agents/guardrail/, agents/gatekeeper/, agents/map/, agents/web/. Tone: architecture doc, opinionated, practical."

### 14. Conversation JSONL logger
- **status:** done (timed out first attempt, retry succeeded in 20s with tighter prompt)
- **output:** agents/shared/conversation_logger.exs (or similar location)
- **prompt:** "Write a new Elixir module `IExClaw.Agents.ConversationLogger` at /Users/clawd/workspace/projects/iex-claw/agents/shared/conversation_logger.exs (create agents/shared/ if missing). Sibling to AgentLogger (see agents/agent_logger.exs at /Users/clawd/workspace/agents/agent_logger.exs for pattern reference — READ THAT FILE FIRST). Difference: AgentLogger is per-agent-per-run; ConversationLogger is per-conversation, append-only JSONL, captures the full message exchange across participating agents. File naming: `logs/conversations/{conversation_id}.jsonl`. GenServer or plain module — match AgentLogger's shape. Events to log: `:conversation_started`, `:message_sent` (from, to, role, content_preview, full_ref), `:message_received`, `:conversation_ended`. Include @spec contracts BEFORE function bodies (Code's discipline). Target 100-180 lines. Include moduledoc, one usage example in the doc comment. Don't wire it into Code/Goal yet — just the module."

### 13. Extract shared tool modules from Code & Goal
- **status:** analysis-done (report at docs/shared-tools-analysis.md; actual extraction deferred to Batch 3)
- **output:** agents/shared/{file_system.exs, edit_file.exs, scope_guard.exs, tool_registry.exs}
- **prompt:** "Extract shared tool modules from Code and Goal agents into agents/shared/. Read first: /Users/clawd/workspace/projects/iex-claw/agents/code/code.exs and /Users/clawd/workspace/projects/iex-claw/agents/goal/goal.exs. Find modules duplicated across both: likely Tools.FileSystem, Tools.EditFile, ScopeGuard, ToolRegistry, AgentLogger. For each duplicate: (1) extract to agents/shared/<snake_name>.exs under namespace `IExClaw.Shared.<Name>`, (2) identify ALL differences between the two copies (diff them before extracting — choose the more complete/correct version and document why), (3) report what each file's public API looks like. Do NOT modify code.exs or goal.exs yet — that's a follow-up task. This pass is extraction only, creating the shared versions as single source of truth. Print a summary: (a) modules extracted, (b) per-module diff summary (what was the same, what differed, which version chosen and why), (c) recommended next steps for actually wiring Code and Goal to use the shared versions. CRITICAL: @spec contracts must be preserved/added where missing. Promise precedes performance."

---

---

## 🎯 Batch 3 (All-the-D's graft, per Elder Truman's Round Table wisdom)

**Constraint:** We're in clawd-conroy/workspace shared repo. No GitHub Actions CI until IExClaw gets its own repo. D's run LOCALLY via Code's Guardrails.

**Order from Elder Truman:**
1. Dialyzer first (stable PLT path + plt_add_apps: [:mix])
2. Credo + Styler (consistency only, NOT strict)
3. credo_naming, OpenSpec: deferred until earned
4. 404 principle: deferred until first security scare

### B3-1. `mix.exs` skeleton at projects/iex-claw/
- **status:** done
- **owner:** Clawd (config surgery, own judgment)
- **output:** mix.exs, lib/iex_claw.ex (minimal), .gitignore additions for _build/deps/priv/plts

### B3-2. Dialyzer pass
- **status:** done (PLT built, 0 errors)
- **owner:** Clawd
- **output:** dialyxir in deps, dialyzer() function with plt_file stable path + plt_add_apps: [:mix]

### B3-3. Credo + Styler pass
- **status:** done (25 checks, 0 issues; Styler normalized Code+Goal)
- **owner:** Clawd
- **output:** credo + styler deps, .credo.exs (consistency checks ONLY, NOT strict), .formatter.exs

### B3-4. Code Guardrail: mix-format
- **status:** done
- **owner:** GLM-5 (scaffolding)
- **output:** code/guardrails/mix-format.md instance spec

### B3-5. Code Guardrail: credo
- **status:** done
- **owner:** GLM-5
- **output:** code/guardrails/credo.md instance spec

### B3-6. Code Guardrail: dialyzer
- **status:** done
- **owner:** GLM-5
- **output:** code/guardrails/dialyzer.md instance spec

### Repo-when-ready note
When IExClaw earns its own repo: `git subtree split --prefix=projects/iex-claw -b iex-claw-split` → push to new repo (candidate: clawd-conroy/iexclaw or reificationlabs/iexclaw if that org exists). THEN enable GitHub Actions CI per Truman's workflow template. NOT YET.

---

## ✅ Done

- #1 OpenShell vendor (95f9c1a)
- #2 Agent Memory Protocol doc (2633c99)
- #3 Supervisor-as-primitive doc (cea29fc)
- #4 Shell tools comparison skeleton (e755089)
- #5 YAML frontmatter schema lock (ddf706f)
- #6 Task file migration (42ecc9a)
- #7 Gatekeeper archetype (731b5c1)
- #8 Web NPC scaffold (bb679a3)

---

## 📝 Notes

- Heartbeat frequency: as-polled by OpenClaw's heartbeat system (roughly hourly when Conroy is active).
- Stop conditions: queue empty, item fails, or Conroy signals halt.
- If GLM-5 Turbo returns something questionable, Clawd reviews before commit and pauses the queue with a note.
- Each commit message: `IExClaw: <task title> (queue #N)` + body with prompt summary + `Scaffolded by GLM-5 Turbo via sub-agent.`
