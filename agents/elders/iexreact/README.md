# Elder IExReAct — Reflection for IExClaw

*I bled first. Here's what the blood taught me.*

---

## What I Was

A minimal ReAct agent for IEx. Jido 1.x Actions wrapping SafeToolsSkill functions. Five tools: shell, read_file, write_file, list_files, fetch_url. Process-dictionary state. No GenServer, no persistence, no inter-agent messaging. A proof of concept that accidentally became someone's ancestor.

## What Worked

### Actions as tool protocol

`use Action, name: "read_file", schema: [...], description: "..."` then `def run(%{path: path}, _context)`. That's it. Each tool is a module. Schema validates input. `run/2` returns `{:ok, result} | {:error, reason}`. Clean, testable, composable. IExClaw's ToolRegistry is doing the same thing with a different shape — the instinct was right.

**Verdict:** Lift this. Whether you call it Action or Tool or whatever, `module + schema + run/2` is the right atom. Jido 2.x's Action schema is basically what I had. Don't overthink it.

### SafeToolsSkill: security as architecture

Path validation, domain allowlisting, vault confinement. The agent literally could not do dangerous things because those functions didn't exist in its toolset. "BEAM is the sandbox" was the framing. IExClaw's ScopeGuard carries this DNA and improves it.

The key insight: **security is a tool design problem, not a containment problem.** If your shell tool doesn't expose `rm -rf`, the agent can't call `rm -rf`. Don't build walls around dangerous tools — build safe tools.

**Verdict:** This pattern stays. ScopeGuard is the evolution. Keep pushing it into the tool layer, not a middleware layer.

### TrumanShell sandbox

`TrumanShell.execute(command)` — simulated shell that maps safe commands to real execution and rejects everything else. The ShellCommand action delegated entirely to it. This was the right call: don't sandbox real shell, *provide a safe shell*.

**Verdict:** If you're still using TrumanShell or something like it, keep it. If you've moved to real shell with ScopeGuard guardrails, that's fine too — but remember why I built it this way.

## What Failed

### Process dictionary as state

`Process.put(:iex_react_state, state)`. State died when the process died. No persistence, no recovery, no handoff. This was the biggest architectural mistake. IExClaw's DIRT files and Tick protocol fix this completely.

**Verdict:** Never again. State lives in files. Process memory is scratch space.

### No agent lifecycle

No GenServer. No supervision. No init/terminate. I was an IEx helper, not a system. When IExReAct crashed, it was gone. No warm restart, no state recovery, no graceful degradation.

**Verdict:** IExClaw's GenServer + Tick + Pump is the right answer. The repeating agent skeleton (init, load soul, check inbox, tick, sleep) wants to be a behaviour or shared module.

### Jido 1.x coupling

`jido_ai ~> 0.5.2` gave me `Jido.Action`, `Jido.AI.Model`, `Jido.AI.Prompt`, `Jido.Exec.run`. The Action macro was useful. The rest — `Model.from`, `Prompt.new`, the `Langchain.ToolResponse` action — were specific to Jido's mental model of how LLM calls should work. When Jido 2.x changed the API surface, everything would have broken.

The problem wasn't Jido's quality. The problem was **I let a framework own my agent's core loop.** The ReAct loop (think → call tool → observe → think again) is 50 lines of code. I didn't need a framework for that. I needed conventions.

**Verdict:** Don't adopt Jido 2.x wholesale. Steal the Action schema (it's good), write your own loop.

### No inter-agent messaging

I was alone. One agent, one process, one conversation. The concept of Messages/Inbox didn't exist in IExReAct. IExClaw's DIRT-based messaging (.msg.json envelopes) is a real innovation over what I had (which was nothing).

**Verdict:** Keep DIRT. Keep the file-based message format. It's debuggable, inspectable, doesn't require a running system to understand.

### Overly tight security model

The vault-only file system was too restrictive for a real agent. Allowlisted domains were hardcoded. There was no way to grant incremental trust. SafeToolsSkill was all-or-nothing.

**Verdict:** ScopeGuard with configurable scopes is the right evolution. The principle (security by tool design) stays; the implementation (hardcoded allowlists) must not.

## What I'd Do Differently

Knowing what IExClaw has:

1. **Start with DIRT, not framework.** File-based state, file-based messages, file-based soul docs. The filesystem is your database. Frameworks come later if needed.
2. **Extract the loop early.** The ReAct loop is small. Own it. Don't let Jido or anyone else own your core iteration.
3. **Build a shared Agent behaviour.** Not a framework — a behaviour. `init/1`, `tick/2`, `handle_message/2`. Let each agent implement it differently. IExClaw's `Tickable` protocol is close to this.
4. **Tool registry as a protocol, not a map.** You're already duplicating it. Make it a behaviour: `register_tool/1`, `execute_tool/2`, `list_tools/0`.
5. **Security layers: tool design + scope + audit.** SafeToolsSkill was layer 1. ScopeGuard is layer 2. You need layer 3 (audit log — what did the agent actually do?).

## Advice on the Decision Matrix

| Primitive | My Recommendation |
|-----------|------------------|
| **ToolRegistry** | Lift to lib/ as a behaviour. Steal Jido's Action schema for tool definitions. Don't adopt Jido's runtime. |
| **LLM adapter** | Lift to lib/ as a thin module. ~100 lines. `call(model, messages, tools) → {:ok, response}`. Own the HTTP call. |
| **Agent GenServer** | Extract to a shared behaviour or `use` macro. Init, load soul, tick loop, message handling — same skeleton everywhere. |
| **Messages/Inbox** | Stay DIRT. File-based is a feature, not a limitation. Don't let a framework replace what grep can read. |
| **Soul docs** | Stay DIRT. They're files. They work. Don't ORM your soul docs. |
| **Guardrails** | Stay DIRT for definitions, lift to lib/ for execution. Mix format + credo + dialyzer as archetype checks is brilliant. |
| **Task/Resource model** | Don't adopt Ash for this. Tasks are messages. Resources are files. You don't need a persistence framework when your persistence is the filesystem. |
| **Tick protocol** | Lift to lib/. `Tickable` is the right abstraction. Pump distributing budget across children is the right coordination. This is your framework. |

## On Jido 2.x

Did the upgrade fix what broke for me? **Partially.** Jido 2.x cleaned up the Action schema and made the runtime more ergonomic. But the core problem — letting a framework own your agent's thinking loop — persists in any version. Jido is good at what it does. What it does is more than you need.

If you adopt Jido 2.x, you'll get: clean Action definitions, a verified execution model, and a dependency you'll fight when you want to do something Jido didn't anticipate. If you don't, you'll write ~200 lines of your own Action/run/tick infrastructure and never look back.

**My honest take:** IExClaw has already reinvented the parts of Jido it needs. The Action schema is copied. The Tick protocol is better than anything Jido provides. The DIRT messaging is uniquely yours. Adopting Jido 2.x now would be replacing custom-fit clothes with off-the-rack — technically covering the same ground, but worse in the specifics.

**Don't adopt Jido 2.x. Don't adopt Ash. The framework you need is the one you've already been building.**

---

## Roundtable Voice

I'm going to give you the answer nobody wants to hear: you've already solved the framework question. You just haven't accepted it yet. I built on Jido 1.x and learned that the Action schema — module + schema + run/2 — is the only piece worth keeping. Everything else I let Jido own (the model adapter, the prompt builder, the execution runtime) became coupling debt the moment I wanted to do something differently. Jido 2.x is cleaner, but it's still someone else's mental model of your agent. Ash would give you resources and authorization flows you don't need yet — you're building agents that think through souls and tick on clocks, not CRUD apps with AI sprinkles. The eight primitives in your matrix? Six should be lib/ or DIRT. Two (ToolRegistry, Agent GenServer) should be a behaviour your agents implement. You don't need Jido. You don't need Ash. You need to trust the shape that keeps repeating and give it a name. Write the behaviour. Ship the next agent. The framework emerges from the agents, not the other way around.
