# MESSAGES.md — Inter-Agent Messaging (DIRT Bus, v0)

*A2A-shaped envelopes. DIRT-stored. No PubSub yet. No Postmaster yet.
Just files + inboxes + "tag, you're it."*

## Why

IExClaw agents need to talk to each other. Goal judges Code. Code consults
Goal. Project asks Goal about proposals. Eventually anyone can CC anyone.

Today we don't have a message bus. Tomorrow we will (Postmaster NPC + DIRT-backed
PubSub). Between today and tomorrow, we need the *envelope shape* to be right
so the bus, when it arrives, just changes the delivery mechanism — not the
semantics.

We borrow the shape from Google's A2A protocol (Task / Message / Part / AgentCard),
but strip the wire format (no JSON-RPC, no HTTP). Files are the wire.

## Layout

```
projects/iex-claw/messages/
├── inbox/
│   ├── code/          # messages waiting for Code to read
│   ├── goal/          # messages waiting for Goal to read
│   ├── project/       # etc.
│   └── clawd/         # Clawd's consultant inbox
├── sent/              # (optional later) archive of delivered messages
└── README.md          # pointer to this spec
```

Each message is a single file: `msg-YYYY-MM-DD-HHMMSS-NNNN.msg.json`.

## Envelope (v0)

```json
{
  "id": "msg-2026-04-05-072400-1847",
  "from": "code",
  "to": "goal",
  "in_reply_to": null,
  "task_id": "llm-adapter-swappability",
  "timestamp": "2026-04-05T11:24:00Z",
  "expects_response": true,
  "parts": [
    { "kind": "text", "text": "Proposal: here's my draft LLM adapter..." },
    { "kind": "file_ref", "path": "projects/iex-claw/code/llm_adapter.exs" }
  ]
}
```

### Required fields
- `id` — unique per message
- `from`, `to` — agent names (directory slugs under `agents/`)
- `task_id` — scopes the conversation to a topic/task
- `timestamp` — ISO-8601 UTC
- `parts` — array of message parts (see below)

### Optional fields
- `in_reply_to` — message id this answers (null for new threads)
- `expects_response` — boolean. Default false.

## Part Kinds

| kind | shape | use |
|------|-------|-----|
| `text` | `{kind, text}` | plain prose |
| `file_ref` | `{kind, path}` | reference to an artifact. **Never copy code — reference it.** |
| `verdict` | `{kind, verdict_type, subject, body}` | Goal's signature (aligned, rewrite, refuse, etc.) |
| `feedback` | `{kind, flavor, observation, impact, request, addressed_to}` | NVC-style policy/behavior feedback (see below) |
| `ping` | `{kind, text?}` | "tag, you're it" — minimal wake signal |
| `ack` | `{kind, text?}` | "LGTM / received / thanks" |
| `structured` | `{kind, schema, data}` | typed payloads (future) |

Unknown `kind` values are OK — agents skip what they don't understand.

## Feedback Parts (NVC-style)

When any agent wants to propose a change in another agent's policy or behavior,
they send a `feedback` part. Shape (adapted from Nonviolent Communication):

```json
{
  "kind": "feedback",
  "flavor": "question" | "comment" | "concern" | "suggestion",
  "observation": "When you did X...",
  "impact": "...it made me Y / I noticed Z.",
  "request": "In the future, I would prefer W." ,
  "addressed_to": "code"
}
```

The four flavors are the **same taxonomy as guardrails** (question blocks hard,
concern blocks soft, comment and suggestion don't block). But feedback parts
are for peer-to-peer policy dialogue, not check sign-offs.

Any agent can send feedback to any other agent (including self-feedback for
reflection). Heartbeats are a natural time to review feedback inbox.

## Message Status Lifecycle (recipient-managed)

Each agent tracks message status in their own `messages/inbox/<self>/_status.json`:

| Status | Meaning |
|--------|---------|
| `unread` | arrived, not yet processed |
| `read` | processed, no action needed |
| `addressed` | acted on (edit made, policy updated, etc.) |
| `replied` | responded via return message |
| `archived` | completed + filed away |
| `waiting` | replied-to + now blocked awaiting external input |
| `irrelevant` | doesn't apply to me; noted and moved on |
| `refused` | considered and declined, with reason logged |

An agent's typical flow on waking: list unread → decide per message → update status.
Archived messages stay on disk under `messages/inbox/<self>/archive/` for lineage.

## Delivery Protocol (today — manual/file-based)

1. Sender writes `.msg.json` file into recipient's `inbox/<to>/`.
2. Recipient reads inbox on wake or on demand.
3. Recipient responds by writing a new `.msg.json` back into sender's
   `inbox/<from>/`, with `in_reply_to` pointing at the original id.
4. No explicit "read" receipt. The response IS the ack (or no-response if
   `expects_response: false`).

**There is no Postmaster yet.** There is no auto-wake yet. Tonight Clawd
manually wires conversations by calling each agent's CLI. That's fine —
we're molting, not planning.

## Delivery Protocol (tomorrow — Postmaster NPC)

Postmaster reads `_subscriptions/<agent>.json` files and fires wake-messages
per the subscription's `wake_on` contract (`:message` / `:heartbeat` / `:never`).
See the Bus sketch in `memory/2026-04-05.md`.

## Conventions

- **One message per file.** Don't batch.
- **Reference, not copy.** If you want to show code, use `file_ref`, not a
  text part containing the code. Moral rights to codelets.
- **Conversations are threads via `in_reply_to` + `task_id`.** Readers can
  reconstruct by walking backward.
- **Inboxes are append-only.** Don't delete messages you've read. Move to
  `sent/` (optional) if archiving.
- **Naming:** lowercase agent slugs (`code`, `goal`, `project`, `clawd`),
  match directory names under `agents/` or `consultants/`.

## Versioning

This is v0. The envelope shape may grow (auth, signatures, extensions per
A2A). The five required fields above are stable.

---

*Borrowed from A2A. Stored in DIRT. The file wins.*
