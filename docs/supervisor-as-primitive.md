# Supervisor as Primitive

Supervisors in IExClaw are structural infrastructure — a general-purpose keep-alive primitive, not a task-scoped role.

---

## The Correction (vs Symphony)

Symphony (OpenAI's Elixir coding-agent harness) models supervisors as **task-scoped**: one supervisor per implementation run, created when a coding task begins, torn down when it completes. This makes perfect sense for Symphony — it's a coding-agent harness. Tasks have clear boundaries. Start, implement, stop.

IExClaw is not a coding-agent harness. It's a **general-purpose agent harness with a bias toward growth and action**. Agents in IExClaw may not have a task at all — they may just be *alive*. An agent might exist to maintain presence, to observe, to respond when provoked. The notion of "supervisor = one per task" collapses when there's no task.

So: supervisors are a **primitive**. Any Agent can host them. They can supervise anything — child agents, Guardrails, Gatekeepers, codelets, heartbeats, long-running I/O. They live as long as the thing they supervise lives. They compose freely. They nest.

This isn't a minor naming distinction. It determines the entire structural vocabulary of the system.

---

## Nesting / Fractal Example

IExClaw's supervision tree is fractal. Turtles all the way down.

```
IExClaw (root)
├── project: truman
│   ├── Agent: safety-layer
│   │   ├── Guardrails-Supervisor
│   │   │   ├── Guardrail: output-filter
│   │   │   └── Guardrail: permission-check
│   │   ├── Gatekeeper: capability-auth
│   │   ├── Codelet-Supervisor
│   │   │   ├── Codelet: rbac-evaluator
│   │   │   └── Codelet: audit-logger
│   │   └── Heartbeat: health-ping (60s)
│   │
│   └── Agent: orchestrator
│       ├── NPC: task-router (deterministic)
│       ├── Codelet-Supervisor
│       │   └── Codelet: http-scraper
│       └── Heartbeat: task-poll (30s)
│
├── project: veryhuman
│   └── Agent: community-bot
│       ├── Codelet-Supervisor
│       └── Heartbeat: presence-check (120s)
│
└── Agent: clawd (personal assistant)
    ├── Guardrails-Supervisor
    ├── Codelet-Supervisor
    └── Heartbeat: system-check (300s)
```

Key observations:
- Each **project** has its own subtree. `truman` dying doesn't take `veryhuman` with it.
- Each **agent** supervises its own children. Guardrails are one subtree, codelets another.
- Heartbeats, codelets, guardrails — all supervised, all independently restartable.
- The tree is dynamic. Agents spawn codelets mid-life. Projects add agents. Growth is expected.

---

## OTP Mapping

IExClaw runs on the BEAM. We use OTP's supervision primitives directly, not reinventing them.

### Base primitives

**Task.Supervisor + Process.monitor** — borrowed from Symphony's pattern (`agents/vendors/symphony/IDENTITY.md`, Patterns-to-Borrow section). Task.Supervisor gives us fire-and-forget supervised tasks. Process.monitor lets us react to crashes without being the supervisor ourselves.

**DynamicSupervisor** — for runtime child addition. When an agent decides mid-conversation to spin up a codelet, DynamicSupervisor handles it. No restart-the-world, no static child spec.

### Restart strategies

IExClaw uses three strategies, each at different levels:

| Strategy | Where | Rationale |
|----------|-------|-----------|
| `:one_for_one` | Codelets, Guardrails, Heartbeats | Independent components. One crashing doesn't affect siblings. |
| `:one_for_all` | Agent + its Gatekeeper | If the gatekeeper dies, the agent can't make safe decisions. Restart everything. |
| `:rest_for_one` | Staged pipelines (future) | If stage 2 dies, stages 3+ must restart because their inputs are gone. Stage 1 stays up. |

For readers unfamiliar with OTP: these strategies answer "when one child crashes, what happens to its siblings?" One-for-one says "nothing, just restart that one." One-for-all says "kill and restart everything." Rest-for-one says "restart this one and everything started after it."

---

## What Supervisors Do NOT Do

This section is as important as what supervisors *do*.

**Supervisors do NOT decide what to run.** That's the Agent's job (LLM-powered intentionality) or the NPC's job (deterministic logic routing). A supervisor doesn't say "you should have a guardrail." The agent decides to have a guardrail; the supervisor keeps it alive.

**Supervisors do NOT hold business logic.** They have exactly one concern: keep-alive + restart. They don't evaluate guardrail results, don't route messages, don't make decisions. Pure structural infrastructure.

**Supervisors do NOT own state.** State lives in the supervised process. When a supervisor restarts a child, the child gets to decide what state to recover (from memory protocol, from disk, from scratch). The supervisor is stateless.

> **⚠️ Misleading task title:** `tasks/supervisor-agent-the-brain-that-delegates.md` implies supervisors are decision-making delegators. They're not. That doc describes an agent architecture pattern, not supervisor behavior. Supervisors don't delegate. They restart.

---

## Patterns / Examples

### Supervisor as Cardiovascular System

Think of a supervisor as an agent's cardiovascular system. It keeps the blood pumping — guardrails, codelets, heartbeats all stay alive. But it doesn't think. The brain (Agent/NPC) decides *what* to run. The cardiovascular system (Supervisor) keeps it running. When something crashes, the heart keeps beating and the component restarts.

### Agent + Guardrails-Supervisor

An agent has two guardrails: output-filter and permission-check. The permission-check crashes (bug in the ACL logic). The Guardrails-Supervisor restarts it. The output-filter never noticed. The agent keeps working. If the guardrail keeps crashing, the supervisor escalates (see Open Questions).

### Agent + Codelet-Supervisor

Codelets are cheap, crashable, restartable workers. An agent spins up an http-scraper codelet. It hits a timeout and crashes. Supervisor restarts it. It hits another timeout and crashes. Supervisor restarts it again. After N failures, the supervisor gives up and reports to the agent. The agent decides to try a different approach.

### Project + Agents-Supervisor

`project: truman` runs two agents. The safety-layer agent hits an unrecoverable state and crashes repeatedly. The Agents-Supervisor for `truman` reports the failure up to the root supervisor. `project: veryhuman` is unaffected — completely independent subtree.

---

## Open Questions

**How does a supervisor communicate "I gave up, child keeps crashing" upward?**
OTP gives us `:max_restarts` and `:max_seconds` — after too many restarts in a window, the supervisor itself gives up. But "give up" in OTP means the supervisor's parent crashes, cascading upward. In IExClaw, we probably want something softer: a notification to the agent ("your guardrail won't stay up") rather than killing the agent. Needs design.

**When does a supervised Guardrail wake its parent agent vs just restart silently?**
Most crashes should be silent restarts — the guardrail had a bug, it came back, life continues. But some crashes are *meaningful*: the guardrail detected something it couldn't handle and intentionally crashed as a signal. How do we distinguish? Exit reasons? A convention for "intentional crash as alarm"?

**Do heartbeats invoke supervisor health checks, or are they independent?**
Heartbeats (periodic "are you alive?" pings) and supervisors (structural keep-alive) serve overlapping purposes. Options: (a) heartbeats are just another supervised process, independent; (b) heartbeat results feed into supervisor health decisions; (c) heartbeats are the mechanism by which supervisors detect liveness beyond crash detection. Leaning toward (a) for simplicity, with (c) as a future enhancement.

---

## Cross-References

- [agents/vendors/symphony/IDENTITY.md](../agents/vendors/symphony/IDENTITY.md) — the source correction; Symphony's task-scoped supervisor model
- [tasks/generalize-supervisor-concept-primitive-not-role.md](../tasks/generalize-supervisor-concept-primitive-not-role.md) — the originating task
- [tasks/supervisor-agent-the-brain-that-delegates.md](../tasks/supervisor-agent-the-brain-that-delegates.md) — ⚠️ misleading title; supervisors don't delegate
- [docs/agent-memory-protocol.md](agent-memory-protocol.md) — sibling architecture doc; how supervised processes recover state after restart
