defmodule IExClaw.Tickable do
  @moduledoc """
  A thing that can be ticked. Agents. NPCs. Projects. Anything with local will.

  A `:tick` is PERMISSION, not INSTRUCTION.
  Parent says "here's a cycle, what do you want?"
  Child decides locally, does at most one unit of work, yields.

  Returning `:idle` is not failure — it's honesty. Most ticks are idle.
  Returning `:work` consumes one unit of the parent's cycle budget.

  "The clock lives in the tick."
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
