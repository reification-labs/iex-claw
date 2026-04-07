# Shell Tools Comparison: TrumanShell / claw-code / NVIDIA OpenShell

Three-way comparison of shell-tool implementations to inform IExClaw tool design.

## Goal

Extract patterns worth borrowing for IExClaw across three concrete vendor implementations:
- Shell-tool patterns and abstractions
- Permission model approaches (allow/deny, RBAC, capability-based)
- Output formatting strategies (structured vs streaming, truncation rules)
- Streaming vs batch execution models
- How tool schemas map to agent request/response protocols

## Comparison Dimensions

- **Tool set coverage** — which tools exist (bash, grep, glob, git, web\_fetch, etc.)
- **Permission model** — how tool invocations are authorized pre-execution
- **Output formatting** — structured (JSON), streaming (stdout passthrough), truncation rules, token budgets
- **Error handling** — how failures, timeouts, and non-zero exits surface to the agent
- **Agent integration pattern** — schema format, protocol (MCP, custom JSON-RPC, inline), tool dispatch loop
- **Sandboxing / isolation** — Docker, nsjail, Firecracker, none; filesystem restrictions
- **Declarative configuration** — YAML policies, TOML, code-level; what's configurable vs hardcoded

## Per-Tool Comparison

### `bash`

| Vendor | Spec shape | Permissions | Output format | Notes |
|--------|-----------|-------------|---------------|-------|
| TrumanShell | <!-- TODO: fill from truman-shell --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| claw-code | <!-- TODO: fill from agents/vendors/claw-code/src/ --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| OpenShell | <!-- TODO: fill from agents/vendors/openshell/src/ --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |

### `grep`

| Vendor | Spec shape | Permissions | Output format | Notes |
|--------|-----------|-------------|---------------|-------|
| TrumanShell | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| claw-code | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| OpenShell | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |

### `glob`

| Vendor | Spec shape | Permissions | Output format | Notes |
|--------|-----------|-------------|---------------|-------|
| TrumanShell | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| claw-code | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| OpenShell | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |

### `git`

| Vendor | Spec shape | Permissions | Output format | Notes |
|--------|-----------|-------------|---------------|-------|
| TrumanShell | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| claw-code | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| OpenShell | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |

### `web_fetch`

| Vendor | Spec shape | Permissions | Output format | Notes |
|--------|-----------|-------------|---------------|-------|
| TrumanShell | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| claw-code | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| OpenShell | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |

## Lessons & Decisions

### Patterns to Adopt for IExClaw
<!-- TODO: fill after deep reads of all three vendors -->

### Patterns to Reject
<!-- TODO: fill after deep reads -->

### Open Questions
<!-- TODO: fill after deep reads -->

## Sources to Read

| Vendor | Path(s) | Focus |
|--------|---------|-------|
| TrumanShell | `~/workspace/truman-shell/` <!-- TODO: confirm --> | Tool definitions, permission checks, agent loop |
| claw-code | `agents/vendors/claw-code/src/` | 40 tool schemas, agent loop, error handling |
| OpenShell | `agents/vendors/openshell/src/crates/openshell-policy/` | YAML policy schema, sandboxing rules |
| OpenShell | `agents/vendors/openshell/src/crates/openshell-server/` | Tool dispatch, agent protocol |

Cross-reference: `tasks/shop-shell-tools-compare-trumanshell-clawcode-nvidia-openshell.md`
