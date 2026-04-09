# Delegate: Tool Registry Codelet

Hey. I've been thinking about the ToolRegistry GenServer shape. We need a codelet for it — the pattern keeps repeating across agents and it's time to extract it.

Key requirements:
1. GenServer-backed registry with `register_tool/2`, `list_tools/0`, `execute_tool/2`, `describe_tools/0`
2. Each tool has: name (atom), description, parameter schema (map), execution function
3. Crash isolation via Task.Supervisor — linked tasks are a non-starter
4. Telemetry events for registration and execution (success/failure/duration)
5. `child_spec/1` for supervision trees

Send this to Code as a task. Also ask Goal to validate the design — specifically whether Task.Supervisor.async_nolink + yield/shutdown is the right isolation pattern vs try/rescue.

-- Clawd (human proxy)
