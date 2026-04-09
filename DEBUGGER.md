# DEBUGGER.md — Debugging Notes & Hard-Won Knowledge

*Things we learned the hard way. Keep these.*

## ExUnit `on_exit` Race with Supervisor Processes

**Discovered:** 2026-04-08 — IExClaw `ToolRegistryServerTest`

### The Bug

Starting a Supervisor in `setup`, stopping it with `Supervisor.stop(sup_pid)` in `on_exit`:

```elixir
setup do
  {:ok, sup_pid} = Supervisor.start_link(children, strategy: :rest_for_one)
  on_exit(fn -> Supervisor.stop(sup_pid) end)
  {:ok, sup_pid: sup_pid}
end
```

This **always fails** with:

```
** (exit) exited in: GenServer.stop(#PID<...>, :normal, :infinity)
    ** (EXIT) no process: the process is not alive
```

### Why It Happens

`Supervisor.stop/1` delegates to `GenServer.stop/3`, which calls `GenServer.call(pid, :stop, timeout)`. This involves:
1. Setting up a monitor on the target process
2. Sending a `:$gen_call` message to the target
3. Waiting for a reply

ExUnit's `on_exit` handlers run in a handler process that's racing with ExUnit's own cleanup. Between step 1 and step 2, ExUnit can kill the supervisor process. Result: `:noproc`.

The supervisor IS alive when `on_exit` starts (verified with `Process.alive?/1`), but dies during the `GenServer.call` message round-trip. Even wrapping in `if Process.alive?(sup_pid)` doesn't help — same race.

### The Fix

Use `Process.exit/2` + `Process.monitor/1` instead:

```elixir
on_exit(fn ->
  ref = Process.monitor(sup_pid)
  Process.exit(sup_pid, :shutdown)
  receive do
    {:DOWN, ^ref, _, _, _} -> :ok
  after
    1000 -> :ok
  end
  Process.demonitor(ref, [:flush])
end)
```

`Process.exit/2` sends a signal directly — no message round-trip, no race. The monitor confirms the process actually exited.

### When It Matters

- Any time you start a GenServer or Supervisor in `setup` and clean up in `on_exit`
- `GenServer.stop/3` and `Supervisor.stop/1` are both vulnerable (both use `GenServer.call`)
- `Process.exit(pid, :shutdown)` triggers a graceful shutdown (the process receives `{:EXIT, _, :shutdown}` and can clean up)
- `Process.exit(pid, :kill)` is the nuclear option — immediate termination, no cleanup

### Lessons

1. **`Process.exit > GenServer.stop` for teardown** — signal vs message, no race possible
2. **Always use a monitor** — confirms the process actually died, gives you a timeout escape hatch
3. **`async: true` vs `async: false` doesn't matter** — this is an ExUnit `on_exit` handler issue, not a concurrency issue
4. **`Supervisor.stop` works fine outside ExUnit** — it's specifically the `on_exit` context that creates the race
5. **Tests were passing all along** — the actual test bodies succeeded. It was only cleanup that failed, but ExUnit reports it as a test failure

## Code Agent Behavior (IExClaw)

### Traffic Lights

- 🟢 GREEN with explicit imperative verbs ("Fix this now. Do not ask permission.") = actually works
- 🟡 YELLOW or no light = Code reads the message, reports understanding, goes to sleep
- `expects_response: true` in inbox messages does NOT trigger autonomous action

### Gaps

- Code has no `run_tests` tool — can't verify its own work
- Code tends to report/delegate rather than close the loop
- Multiple "go now" messages may be needed before Code acts
