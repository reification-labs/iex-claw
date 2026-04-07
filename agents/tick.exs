# IExClaw.Tick
#
# The pump. Blood in the circuit. Electrons in the gates.
#
# A `:tick` is PERMISSION, not INSTRUCTION.
# Parent says "here's a cycle, what do you want?"
# Child decides locally, does at most one unit of work, yields.
#
# Contract:
#   - A Tickable implements `tick(state, budget) :: {:work, summary, new_state}
#                                               | {:idle, new_state}`
#   - One tick = at most ONE unit of work (one read, one write, one LLM call)
#   - Idle ticks are free. Only `:work` consumes budget.
#   - Multi-step intentions emerge from repetition across cycles.
#
# Usage:
#   elixir agents/tick.exs            # runs the demo
#
# The contract (@callback) is written BEFORE the implementation.
# The promise precedes the performance.

# --- The Behaviour ---
# What it means to be Tickable.

defmodule IExClaw.Tickable do
  @moduledoc """
  A thing that can be ticked. Agents. NPCs. Projects. Anything with local will.

  Returning `:idle` is not failure — it's honesty. Most ticks are idle.
  Returning `:work` consumes one unit of the parent's cycle budget.
  """

  @type summary :: String.t()
  @type state :: term()
  @type tick_result :: {:work, summary, state} | {:idle, state}

  @type clock :: %{clock: String.t()}

  @doc """
  Receive one tick. The `meta` map always contains `:clock` (ISO-8601 UTC).
  Return `{:work, summary, new_state}` or `{:idle, new_state}`.
  """
  @callback tick(state, meta :: clock()) :: tick_result
end

# --- The Pump ---
# Parent hands cycles to children. Children decide what to do.

defmodule IExClaw.Tick.Pump do
  @moduledoc """
  Pump a cycle across a set of tickable children.

  Each child gets one `tick/1` call per cycle. Work results are collected.
  Budget bounds total `:work` responses per cycle — if the budget is spent,
  remaining children get zero ticks this cycle (they'll try next cycle).

  This is backpressure without a global scheduler. The parent owns the clock.
  """

  @type child :: {name :: atom() | String.t(), module :: module(), state :: term()}
  @type cycle_result :: %{
          worked: [{name :: term(), summary :: String.t()}],
          idled: [name :: term()],
          skipped: [name :: term()],
          states: %{optional(term()) => term()}
        }

  @spec cycle([child()], budget :: non_neg_integer(), meta :: map()) :: cycle_result()
  def cycle(children, budget \\ 10, meta \\ %{}) do
    meta = Map.put_new(meta, :clock, DateTime.to_iso8601(DateTime.utc_now()))
    initial = %{worked: [], idled: [], skipped: [], states: %{}, budget: budget}

    result =
      Enum.reduce(children, initial, fn {name, mod, state}, acc ->
        cond do
          acc.budget <= 0 ->
            %{acc | skipped: [name | acc.skipped], states: Map.put(acc.states, name, state)}

          true ->
            case safe_tick(mod, state, meta) do
              {:work, summary, new_state} ->
                %{
                  acc
                  | worked: [{name, summary} | acc.worked],
                    budget: acc.budget - 1,
                    states: Map.put(acc.states, name, new_state)
                }

              {:idle, new_state} ->
                %{acc | idled: [name | acc.idled], states: Map.put(acc.states, name, new_state)}

              other ->
                %{
                  acc
                  | worked: [{name, "⚠️  invalid tick response: #{inspect(other)}"} | acc.worked],
                    states: Map.put(acc.states, name, state)
                }
            end
        end
      end)

    result
    |> Map.drop([:budget])
    |> Map.update!(:worked, &Enum.reverse/1)
    |> Map.update!(:idled, &Enum.reverse/1)
    |> Map.update!(:skipped, &Enum.reverse/1)
  end

  @spec safe_tick(module(), term(), map()) :: IExClaw.Tickable.tick_result() | term()
  defp safe_tick(mod, state, meta) do
    mod.tick(state, meta)
  rescue
    e -> {:work, "💥 crashed: #{Exception.message(e)}", state}
  end
end

# --- Stub Agents ---
# Minimal Tickables that demonstrate the protocol.
# No LLMs, no tokens — just will and state.

# A counter that ticks up to a target, then goes idle forever.
defmodule Demo.Counter do
  @behaviour IExClaw.Tickable

  defstruct name: "counter", count: 0, target: 3

  @impl true
  def tick(%__MODULE__{count: c, target: t, name: n} = state, _meta) when c < t do
    {:work, "#{n}: counted to #{c + 1}/#{t}", %{state | count: c + 1}}
  end

  def tick(%__MODULE__{} = state, _meta) do
    {:idle, state}
  end
end

# A scribe that writes one line per tick from a planned script.
# When the script is empty, it's idle. This is the common agent shape:
# "I had a plan, I did one step, here's what's left."
defmodule Demo.Scribe do
  @behaviour IExClaw.Tickable

  defstruct name: "scribe", plan: [], written: []

  @impl true
  def tick(%__MODULE__{plan: []} = state, _meta), do: {:idle, state}

  def tick(%__MODULE__{plan: [next | rest], written: done, name: n} = state, _meta) do
    {:work, "#{n}: wrote '#{next}' (#{length(done) + 1} done, #{length(rest)} left)",
     %{state | plan: rest, written: [next | done]}}
  end
end

# A lazy agent that only works every 3rd tick. Rate-limited will.
defmodule Demo.Lazy do
  @behaviour IExClaw.Tickable

  defstruct name: "lazy", seen: 0, did: 0

  @impl true
  def tick(%__MODULE__{seen: s, did: d, name: n} = state, _meta) do
    seen = s + 1

    if rem(seen, 3) == 0 do
      {:work, "#{n}: worked on tick #{seen} (#{d + 1} total)",
       %{state | seen: seen, did: d + 1}}
    else
      {:idle, %{state | seen: seen}}
    end
  end
end

# --- The Demo ---
# Project runs the clock. Children decide what they want.

defmodule Demo.Run do
  def go do
    IO.puts("\n🦞 IExClaw Tick Protocol — Demo\n")
    IO.puts("Project pumps blood. Children decide locally.")
    IO.puts(String.duplicate("─", 60))

    children = [
      {:counter, Demo.Counter, %Demo.Counter{target: 3}},
      {:scribe, Demo.Scribe, %Demo.Scribe{plan: ["hello", "world", "🦞", "tick", "done"]}},
      {:lazy, Demo.Lazy, %Demo.Lazy{}}
    ]

    # Run 6 cycles with a generous budget.
    run_cycles(children, 1, 6, budget: 10)

    IO.puts(String.duplicate("─", 60))
    IO.puts("\nNow rerun with budget=1 — watch backpressure kick in.\n")
    IO.puts(String.duplicate("─", 60))

    tight = [
      {:counter, Demo.Counter, %Demo.Counter{target: 5}},
      {:scribe, Demo.Scribe, %Demo.Scribe{plan: ["a", "b", "c"]}},
      {:lazy, Demo.Lazy, %Demo.Lazy{}}
    ]

    run_cycles(tight, 1, 6, budget: 1)

    IO.puts(String.duplicate("─", 60))
    IO.puts("\n✨ Blood pumped. Gates clocked. No tokens spent.\n")
  end

  defp run_cycles(_children, n, max, _opts) when n > max, do: :ok

  defp run_cycles(children, n, max, opts) do
    budget = Keyword.get(opts, :budget, 10)
    result = IExClaw.Tick.Pump.cycle(children, budget)

    IO.puts("\n⏱  cycle #{n}  (budget=#{budget})")

    Enum.each(result.worked, fn {name, summary} ->
      IO.puts("  💪 #{name}: #{summary}")
    end)

    if result.idled != [] do
      IO.puts("  😴 idle: #{Enum.map_join(result.idled, ", ", &to_string/1)}")
    end

    if result.skipped != [] do
      IO.puts("  ⏭  skipped (budget spent): #{Enum.map_join(result.skipped, ", ", &to_string/1)}")
    end

    # Rebuild children list from the returned states.
    next_children =
      Enum.map(children, fn {name, mod, _old} ->
        {name, mod, Map.fetch!(result.states, name)}
      end)

    run_cycles(next_children, n + 1, max, opts)
  end
end

# --- Run it when invoked directly ---
# When loaded as a library (Code.require_file), skip the demo.
# Set IEXCLAW_SKIP_DEMO=1 to skip even on direct runs.
if System.get_env("IEXCLAW_SKIP_DEMO") != "1" do
  Demo.Run.go()
end
