defmodule IExClaw.Tick.PumpTest do
  use ExUnit.Case, async: true

  alias IExClaw.Tick.Pump

  # Stub tickables for testing
  defmodule Worker do
    @behaviour IExClaw.Tickable

    defstruct count: 0, target: 2

    @impl true
    def tick(%__MODULE__{count: c, target: t} = state, meta) when c < t do
      # Verify clock is present
      true = is_binary(meta[:clock])
      {:work, "worked #{c + 1}/#{t}", %{state | count: c + 1}}
    end

    def tick(%__MODULE__{} = state, _meta), do: {:idle, state}
  end

  defmodule Crasher do
    @behaviour IExClaw.Tickable

    defstruct []

    @impl true
    def tick(_state, _meta), do: raise("boom")
  end

  describe "cycle/3" do
    test "distributes ticks and collects work results" do
      children = [
        {:a, Worker, %Worker{target: 1}},
        {:b, Worker, %Worker{target: 1}}
      ]

      result = Pump.cycle(children, 10)

      assert length(result.worked) == 2
      assert result.idled == []
      assert result.skipped == []
      assert Map.has_key?(result.states, :a)
      assert Map.has_key?(result.states, :b)
    end

    test "respects budget — skips children when budget spent" do
      children = [
        {:a, Worker, %Worker{target: 3}},
        {:b, Worker, %Worker{target: 3}}
      ]

      result = Pump.cycle(children, 1)

      assert length(result.worked) == 1
      assert [{:a, _}] = result.worked
      assert result.skipped == [:b]
    end

    test "idle children don't consume budget" do
      children = [
        {:done, Worker, %Worker{count: 2, target: 2}},
        {:active, Worker, %Worker{target: 1}}
      ]

      result = Pump.cycle(children, 1)

      assert result.idled == [:done]
      assert [{:active, _}] = result.worked
      assert result.skipped == []
    end

    test "injects clock into meta automatically" do
      children = [{:w, Worker, %Worker{target: 1}}]
      result = Pump.cycle(children, 1)
      assert [{:w, "worked 1/1"}] = result.worked
    end

    test "accepts explicit clock in meta" do
      children = [{:w, Worker, %Worker{target: 1}}]
      result = Pump.cycle(children, 1, %{clock: "2026-04-05T00:00:00Z"})
      assert [{:w, _}] = result.worked
    end

    test "handles crashes gracefully" do
      children = [{:c, Crasher, %Crasher{}}]
      result = Pump.cycle(children, 1)
      assert [{:c, summary}] = result.worked
      assert summary =~ "crashed"
    end
  end
end
