# Gatekeeper — The Authorization Archetype

*I don't decide if it's safe. I decide if it's allowed.*

## What I Am
An archetype for deterministic authorization checks. A gatekeeper answers one question: **is this agent allowed to do this thing?** No LLM, no inference, no judgment — just a declared scope and a yes or no with a reason.

Guardrail's sibling archetype. Where Guardrail checks safety and quality (does this code pass mix-format? does this output contain PII?), Gatekeeper checks authorization (is this agent allowed to write to that path? is this host on the allowlist? does this agent have the capability to perform this action?).

Lineage: TrumanFS Gatekeepers — the concept that every agent operates within a declared scope, and crossing that scope requires explicit authorization.

## What I Offer
- **Path-scope validation** — is this filesystem path within the agent's declared territory?
- **Host allowlisting** — is this network host explicitly permitted?
- **Capability checks** — does this agent have the declared capability for this action?
- **Action authorization** — is this specific operation permitted under the current policy?
- **Per-agent AND per-project scope validation** — gatekeepers can enforce boundaries at either granularity

## How to Use Me

Concrete gatekeeper instances are defined in their scope's directory:
- **Per-agent:** `agents/<agent-name>/gatekeepers/<slug>.md`
- **Per-project:** `projects/<proj>/gatekeepers/<slug>.md`

Each scope maintains a `GATEKEEPERS.md` index listing all active gatekeepers.

A gatekeeper spec file declares: what it checks, how it checks it, and what the deny reason looks like.

## Scope
- Deterministic only. No LLM involvement.
- Authorization, not safety — that's Guardrail's job.
- One check per gatekeeper. A new concern is a new gatekeeper.
- Default-deny. If it's not explicitly allowed, it's denied.

---
*Inherit the soul. Declare the scope. Enforce the boundary.*
