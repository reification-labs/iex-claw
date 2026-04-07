defmodule IExClaw.Mode do
  @moduledoc """
  Agent operating modes — constrained tool sets per phase.

  "Haz lo que debes." — Do what you must.

  A Mode defines:
  - A name (atom)
  - A tool set (subset of the agent's full tools)
  - An output schema (what the agent MUST produce to exit this mode)
  - A transition (what mode comes next on success)

  The key insight: telling an agent "don't use tool X" doesn't work.
  REMOVING tool X from the registry does. The phone goes in another room.

  ## The Contract

  When a Supervisor assigns a Mode to an Agent:
  1. The Agent's ToolRegistry is replaced with the Mode's tool subset
  2. The Agent MUST produce output matching the Mode's schema to transition
  3. If the Agent exhausts its budget without producing valid output → restart
  4. The Agent's SOUL/IDENTITY/PHILOSOPHY survive restart (DIRT persists)
  5. Only the conversation state is lost (the shell, not the lobster)

  "Good luck. Have fun. Don't die."

  ## Usage

      survey_mode = IExClaw.Mode.new(:survey,
        tools: [:read_file, :list_dir, :file_size],
        output: :json_plan,
        next: :execute
      )

      execute_mode = IExClaw.Mode.new(:execute,
        tools: [:read_file, :edit_file, :file_size],
        output: :step_result,
        next: :verify
      )

      verify_mode = IExClaw.Mode.new(:verify,
        tools: [:read_file, :list_dir, :file_size],
        output: :verification_report,
        next: :done
      )
  """

  @type mode_name :: atom()
  @type output_type :: atom()

  @type t :: %__MODULE__{
          name: mode_name(),
          tools: [atom()],
          output: output_type(),
          next: mode_name() | :done,
          max_budget: non_neg_integer(),
          restart_on_budget_exhaustion: boolean(),
          description: String.t()
        }

  @enforce_keys [:name, :tools, :output]
  defstruct [
    :name,
    :tools,
    :output,
    next: :done,
    max_budget: 5,
    restart_on_budget_exhaustion: true,
    description: ""
  ]

  @doc "Create a new Mode."
  @spec new(mode_name(), keyword()) :: t()
  def new(name, opts \\ []) do
    %__MODULE__{
      name: name,
      tools: Keyword.fetch!(opts, :tools),
      output: Keyword.fetch!(opts, :output),
      next: Keyword.get(opts, :next, :done),
      max_budget: Keyword.get(opts, :max_budget, 5),
      restart_on_budget_exhaustion: Keyword.get(opts, :restart_on_budget_exhaustion, true),
      description: Keyword.get(opts, :description, "")
    }
  end

  @doc """
  Filter a full tools map down to only the tools allowed in this mode.

  Tools not in the mode's allowed list are removed entirely — the agent
  physically cannot call them. The phone is in another room.
  """
  @spec filter_tools(t(), IExClaw.ToolRegistry.tools_map()) :: IExClaw.ToolRegistry.tools_map()
  def filter_tools(%__MODULE__{tools: allowed}, full_tools) do
    allowed_strings = Enum.map(allowed, &to_string/1)
    Map.filter(full_tools, fn {name, _} -> name in allowed_strings end)
  end
end
