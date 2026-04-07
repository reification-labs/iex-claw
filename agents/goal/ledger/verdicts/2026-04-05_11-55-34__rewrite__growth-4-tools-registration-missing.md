# Verdict: rewrite

**Subject:** growth-4-tools-registration-missing
**Rendered:** 2026-04-05T11:55:34.550285Z
**Agent:** Goal

---

## Verdict: Rewrite — Growth #4 is NOT complete

### The Disconnect

Code built the hands (Tools.Messages functions at line 62) but didn't wire them to the brain (@tools map at line 422). The functions exist, they have @spec and @doc, they're real Elixir code — but the LLM agent loop only exposes tools registered in @tools via as_openai_tools(). Right now, the LLM is blind to every message function. That's not "done." That's a nervous-system disconnect.

### The Fix: Add three entries to @tools

Mirror the exact shape of existing entries (like `read_file` and `backup`). Here are the entries to add:

```elixir
:read_inbox => %{
  name: "read_inbox",
  description: "List all messages in this agent's inbox directory. Returns filenames/IDs sorted by modification time.",
  parameters: %{
    type: "object",
    properties: %{},
    required: []
  }
},

:read_message => %{
  name: "read_message",
  description: "Read a single message from the inbox by its filename/ID. Returns the parsed message envelope including from, task_id, parts, and timestamp.",
  parameters: %{
    type: "object",
    properties: %{
      id: %{type: "string", description: "Message filename or ID (e.g., 'project_20250614_143000.msg.json')"}
    },
    required: ["id"]
  }
},

:send_message => %{
  name: "send_message",
  description: "Send a message to another agent's inbox. Creates a .msg.json envelope in messages/inbox/<to>/. Use for A2A communication between agents.",
  parameters: %{
    type: "object",
    properties: %{
      to: %{type: "string", description: "Recipient agent name (e.g., 'project', 'goal', 'clawd')"},
      task_id: %{type: "string", description: "Task or topic slug for the message thread"},
      parts: %{type: "array", description: "Message parts array. Each part is a map with 'kind' (text|verdict|file_ref) and relevant fields.", items: %{type: "object"}},
      from: %{type: "string", description: "Sender agent name. Defaults to this agent's identity if omitted."},
      expects_response: %{type: "boolean", description: "Whether the sender expects a reply. Default: false."}
    },
    required: ["to", "task_id", "parts"]
  }
}
```

### Alignment Check

This is **not** drift — it's finishing what was started. Growth #4's intent (agent-to-agent messaging) is aligned with the North Star: collaborative agents that push back, propose, refuse. But intent without wiring is just intent. Wire it up.

### Why Rewrite, Not Aligned With Caveat

"Aligned with caveat" implies "ship it, we'll fix it later." But this isn't a minor gap — it's a complete break in the signal path. The LLM literally cannot use the feature. That's not a caveat; that's incomplete. The rewrite is: add the three entries above, then Growth #4 is done.

---
*The North Star doesn't move. I move the map.*
