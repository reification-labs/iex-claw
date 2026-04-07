defmodule IExClaw.RunLogger do
  @moduledoc """
  DIRT-backed event logger for agent runs.

  Appends structured JSONL events to `logs/runs/<run_id>.events.jsonl`.
  Each line is a self-contained event with core fields + optional context.

  ## Usage

  Build a callback and pass it via `on_event` opt to `agent_loop/3`:

      run_id = RunLogger.generate_run_id("code", "self-surgery")
      on_event = RunLogger.callback(run_id, workplace)

      Agent.agent_loop(state, &ToolRegistry.execute/2,
        on_event: on_event,
        agent_name: "Code"
      )

  Or emit events manually:

      RunLogger.emit(run_id, workplace, "tool_call", %{name: "edit_file", args: %{}})

  ## Event Schema (from Roundtable 2026-04-06)

  Core (every event):
    - ts: ISO-8601 timestamp
    - run_id: unique run identifier
    - seq: monotonic sequence number within run
    - agent: agent name
    - model: model identifier
    - event: event type string
    - data: type-specific payload map

  Context (merged when available):
    - phase: survey | execute | verify
    - step_id: PlanExecute step identifier
    - round: current round number
    - budget: total budget
    - budget_remaining: remaining budget
    - total_calls: running tool call count

  "The JSONL IS the run, not a diary about it."
  — Events-Logs-Bus Roundtable, unanimous
  """

  @type event_type :: String.t()
  @type event_data :: map()
  @type context :: map()
  @type on_event :: (event_type(), event_data(), context() -> :ok)

  @doc """
  Generate a run ID from agent name and goal slug.

  Format: `<agent>-<date>T<time>-<slug>`
  """
  @spec generate_run_id(String.t(), String.t()) :: String.t()
  def generate_run_id(agent, goal_slug \\ "run") do
    ts = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%dT%H-%M-%S")
    slug = goal_slug |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.slice(0, 40)
    "#{agent}-#{ts}-#{slug}"
  end

  @doc """
  Build an `on_event` callback that appends JSONL to a run file.

  Returns a 3-arity function: `fn(event_type, data, context) -> :ok`
  """
  @spec callback(String.t(), Path.t(), keyword()) :: on_event()
  def callback(run_id, workplace, opts \\ []) do
    agent = Keyword.get(opts, :agent, "unknown")
    model = Keyword.get(opts, :model, "unknown")
    seq_ref = :atomics.new(1, signed: false)

    fn event_type, data, context ->
      seq = :atomics.add_get(seq_ref, 1, 1)
      emit(run_id, workplace, event_type, data, Map.merge(context, %{agent: agent, model: model, seq: seq}))
    end
  end

  @doc """
  Emit a single event to the run's JSONL file.
  """
  @spec emit(String.t(), Path.t(), event_type(), event_data(), context()) :: :ok
  def emit(run_id, workplace, event_type, data, context \\ %{}) do
    dir = Path.join(workplace, "logs/runs")
    File.mkdir_p!(dir)
    path = Path.join(dir, "#{run_id}.events.jsonl")

    event =
      maybe_merge_context(
        %{
          ts: DateTime.to_iso8601(DateTime.utc_now()),
          run_id: run_id,
          seq: Map.get(context, :seq, 0),
          agent: Map.get(context, :agent, "unknown"),
          model: Map.get(context, :model, "unknown"),
          event: event_type,
          data: data
        },
        context
      )

    line = Jason.encode!(event) <> "\n"
    File.write!(path, line, [:append])
    :ok
  end

  @doc """
  No-op callback for when event logging is disabled.
  """
  @spec noop() :: on_event()
  def noop do
    fn _event_type, _data, _context -> :ok end
  end

  # Merge harness-specific context fields (phase, step_id, budget, etc.)
  # but exclude internal fields that are already in the core event.
  @context_keys ~w[phase step_id round budget budget_remaining total_calls]a

  defp maybe_merge_context(event, context) do
    ctx =
      context
      |> Map.take(@context_keys)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    if map_size(ctx) > 0 do
      Map.put(event, :context, ctx)
    else
      event
    end
  end
end
