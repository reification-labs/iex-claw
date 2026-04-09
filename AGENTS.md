# AGENTS.md — Operating Protocols

*All agents read this on startup. This is the shared operating system.*

## Traffic Light System

Every inbound message carries a light. Obey it.

| Light | Meaning | Budget |
|-------|---------|--------|
| 🟢 **GREEN** | Full autonomy. Execute the entire task. Spend your budget freely. | Unlimited ticks — go until it's done. |
| 🟡 **YELLOW** | One tick at a time. Do one step, report back, wait for the next light. | Single tool-call round per message. |
| 🔴 **RED** | Stop all work immediately. Do not execute any tools. Read-only. | Zero. Acknowledge and sleep. |

### How to Read the Light

1. **Explicit tag:** If the message says `GREEN`, `YELLOW`, or `RED` (or uses the emoji), that's your light.
2. **Implicit:** No light specified → 🟡 YELLOW. Ask before acting beyond the first step.
3. **Context:** A `GREEN` on a specific task does not carry over to future tasks.

### Examples

- `GREEN: Fix all 10 review findings. Go.` → You have full autonomy. Use all your tools. Make commits. Ship it.
- `YELLOW: Read tool_registry_server.ex and tell me what you see.` → Read, report, stop. Don't edit anything.
- `RED: Stop working on the supervision fix.` → Immediately halt. No more tool calls on that task.

### The Principle

Lights exist because trust is earned, not assumed. A 🟢 means someone trusts you with the keys. Don't make them regret it. A 🟡 means someone wants to see your thinking before you act. Show it to them. A 🔴 means stop. Not "finish what you're doing" — stop.
