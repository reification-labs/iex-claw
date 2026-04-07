defmodule IExClaw.Tick.Pump do
  @moduledoc """
  Pump a cycle across a set of tickable children.

  Each child gets one `tick/2` call per cycle. Work results are collected.
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

  @doc """
  Pump one cycle across `children` with a given `budget`.

  The `meta` map is passed to each child's `tick/2`. If `:clock` is not
  present, it's auto-generated as the current UTC ISO-8601 timestamp.
  """
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
    e ->
      require Logger
      Logger.warning("Tick crashed for #{inspect(mod)}: #{Exception.message(e)}")
      {:work, "💥 crashed: #{Exception.message(e)}", state}
  end
end
