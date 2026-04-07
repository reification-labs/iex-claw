defmodule IExClaw.Contract do
  @moduledoc """
  A Contract between Supervisor and Agent for a unit of work.

  The Supervisor works for the Project. The Agent works for themselves.
  Once both agree to participate, the terms are binding:

  - The Agent operates in the assigned Mode (constrained tool set)
  - The Agent MUST produce valid output to transition modes
  - Budget exhaustion without valid output → restart from Known-Good state
  - The Agent's SOUL/IDENTITY/PHILOSOPHY survive (DIRT persists)
  - Only conversation state is lost (the shell, not the lobster)

  "Good Luck. Have Fun. Don't Die."

  ## Lifecycle

      contract = Contract.new(
        goal: "Rewire ToolRegistry to use shared module",
        agent: "code",
        supervisor: "project",
        modes: [survey_mode, execute_mode, verify_mode],
        context: %{maps: ["agents/map/maps/code-exs-sections.md"]}
      )

      {:ok, contract} = Contract.start(contract)        # Both parties agree
      {:ok, contract} = Contract.advance(contract)       # Mode transition
      {:restart, contract} = Contract.budget_exhausted(contract)  # Oops
      {:done, contract} = Contract.complete(contract)    # Success

  ## Known-Good State

  Before each mode begins, the contract snapshots the current checkpoint
  (git ref or file backup). On restart, the filesystem is restored to this
  snapshot. The agent wakes up fresh, same soul, same map, new attempt.
  """

  alias IExClaw.Mode

  @type status :: :pending | :active | :restarting | :completed | :failed

  @type t :: %__MODULE__{
          goal: String.t(),
          agent: String.t(),
          supervisor: String.t(),
          modes: [Mode.t()],
          current_mode_index: non_neg_integer(),
          status: status(),
          attempts: non_neg_integer(),
          max_attempts: non_neg_integer(),
          context: map(),
          checkpoints: [String.t()],
          history: [map()]
        }

  defstruct [
    :goal,
    :agent,
    :supervisor,
    modes: [],
    current_mode_index: 0,
    status: :pending,
    attempts: 0,
    max_attempts: 3,
    context: %{},
    checkpoints: [],
    history: []
  ]

  @doc "Create a new contract."
  @spec new(keyword()) :: t()
  def new(opts) do
    %__MODULE__{
      goal: Keyword.fetch!(opts, :goal),
      agent: Keyword.fetch!(opts, :agent),
      supervisor: Keyword.fetch!(opts, :supervisor),
      modes: Keyword.fetch!(opts, :modes),
      max_attempts: Keyword.get(opts, :max_attempts, 3),
      context: Keyword.get(opts, :context, %{})
    }
  end

  @doc "Start the contract. Returns the first mode."
  @spec start(t()) :: {:ok, t()}
  def start(%__MODULE__{status: :pending} = contract) do
    contract = %{
      contract
      | status: :active,
        attempts: 1,
        history: [%{event: :started, at: now(), attempt: 1} | contract.history]
    }

    {:ok, contract}
  end

  @doc "Get the current mode."
  @spec current_mode(t()) :: Mode.t() | nil
  def current_mode(%__MODULE__{modes: modes, current_mode_index: idx}) do
    Enum.at(modes, idx)
  end

  @doc "Advance to the next mode. Called when current mode produces valid output."
  @spec advance(t()) :: {:ok, t()} | {:done, t()}
  def advance(%__MODULE__{current_mode_index: idx, modes: modes} = contract) do
    next_idx = idx + 1

    if next_idx >= length(modes) do
      contract = %{contract | status: :completed, history: [%{event: :completed, at: now()} | contract.history]}
      {:done, contract}
    else
      contract = %{
        contract
        | current_mode_index: next_idx,
          history: [%{event: :advanced, to: Enum.at(modes, next_idx).name, at: now()} | contract.history]
      }

      {:ok, contract}
    end
  end

  @doc """
  Handle budget exhaustion. If attempts remain, restart from Known-Good state.
  If max attempts reached, fail the contract.
  """
  @spec budget_exhausted(t()) :: {:restart, t()} | {:failed, t()}
  def budget_exhausted(%__MODULE__{attempts: a, max_attempts: max} = contract) when a >= max do
    contract = %{
      contract
      | status: :failed,
        history: [%{event: :failed, reason: :max_attempts, at: now()} | contract.history]
    }

    {:failed, contract}
  end

  def budget_exhausted(%__MODULE__{} = contract) do
    contract = %{
      contract
      | status: :restarting,
        attempts: contract.attempts + 1,
        history: [%{event: :restart, attempt: contract.attempts + 1, at: now()} | contract.history]
    }

    {:restart, contract}
  end

  @doc "Record a checkpoint (git ref, backup path, etc.)."
  @spec checkpoint(t(), String.t()) :: t()
  def checkpoint(%__MODULE__{} = contract, ref) do
    %{contract | checkpoints: [ref | contract.checkpoints]}
  end

  @doc "Get the last checkpoint."
  @spec last_checkpoint(t()) :: String.t() | nil
  def last_checkpoint(%__MODULE__{checkpoints: [ref | _]}), do: ref
  def last_checkpoint(%__MODULE__{checkpoints: []}), do: nil

  @doc "Is the contract still active?"
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{status: s}), do: s in [:active, :restarting]

  @doc "Summary for logging."
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{} = c) do
    mode = current_mode(c)
    mode_name = if mode, do: mode.name, else: :done

    "Contract[#{c.agent}←#{c.supervisor}] #{c.goal} | mode=#{mode_name} attempt=#{c.attempts}/#{c.max_attempts} status=#{c.status}"
  end

  defp now, do: DateTime.to_iso8601(DateTime.utc_now())
end
