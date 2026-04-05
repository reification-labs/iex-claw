# Supervisor agent — the brain that delegates

**Status:** todo
**Tags:** agent, core, reasoning
**Created:** 2026-04-05 05:15 UTC

## Description

Not an OTP Supervisor (that's infrastructure). This is my prefrontal cortex — the agent that receives a high-level task and decides which other agents to spin up, in what order, with what context. Uses Jido 2.x reasoning strategies to pick an approach. "Fix the failing test" → spin up Reader (read test), TestRunner (see failure), Coder (fix it), Reviewer (check fix), TestRunner (verify). The orchestrator. The one that turns intent into execution.
