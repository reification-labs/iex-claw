defmodule IExClaw.Strategies.PlanExecute do
  @moduledoc """
  Plan-Execute strategy for multi-step agent work.

  "Make the change easy (warning: this may be hard), then make the easy change."
  — Kent Beck

  Instead of feeding an agent one big task, this strategy decomposes work into:

  1. **Survey** — Agent reads the relevant files and outputs a plan
     (a list of narrow, concrete steps).
  2. **Execute** — Each step becomes a separate tick. One edit, one read,
     one small change per tick. Budget-bounded.
  3. **Verify** — Agent checks the result (run tests, read output, confirm).

  The plan is stored as a list of step maps in the strategy state.
  Each step has a `:status` (`:pending`, `:done`, `:failed`, `:skipped`).

  ## Why This Exists

  GLM-5 Turbo (and most models) fail on broad tasks that require holding
  >15KB of context. They succeed on narrow tasks with 2-4KB of focused context.
  The lesson from IExClaw's first molt: "Budget tight → narrow task → one edit → works."

  This strategy makes the agent's OWN context management explicit:
  - Survey phase: read widely, plan narrowly
  - Execute phase: read only what this step needs, do one thing
  - Verify phase: check the whole, not the part

  ## Usage

  The strategy is a data structure, not a GenServer. It's meant to be
  stored in agent state and advanced by the tick protocol.

      state = PlanExecute.new("refactor Code to use shared lib/ modules")
      state = PlanExecute.set_plan(state, [
        %{id: "step-1", task: "Replace ToolRegistry with delegation", files: ["code.exs"], lines: "156-270"},
        %{id: "step-2", task: "Replace agent_loop with IExClaw.Agent.agent_loop/3", files: ["code.exs"], lines: "440-530"},
      ])

      # Each tick:
      case PlanExecute.current_step(state) do
        nil -> :all_done
        step -> # feed step.task to the LLM as a narrow prompt
      end

  ## Tick Integration

  A PlanExecute-aware Tickable can use this as its internal state machine:

      def tick(state, meta) do
        case PlanExecute.phase(state.strategy) do
          :survey -> # LLM reads files, outputs plan
          :execute -> # LLM executes current step
          :verify -> # LLM runs tests / checks
          :done -> {:idle, state}
        end
      end
  """

  @type step :: %{
          id: String.t(),
          task: String.t(),
          status: :pending | :done | :failed | :skipped,
          files: [String.t()],
          lines: String.t() | nil,
          result: String.t() | nil
        }

  @type phase :: :survey | :execute | :verify | :done

  @type t :: %__MODULE__{
          goal: String.t(),
          phase: phase(),
          plan: [step()],
          current_step_index: non_neg_integer(),
          survey_result: String.t() | nil,
          verify_result: String.t() | nil,
          errors: [String.t()]
        }

  defstruct goal: "",
            phase: :survey,
            plan: [],
            current_step_index: 0,
            survey_result: nil,
            verify_result: nil,
            errors: []

  # --- Construction ---

  @doc "Create a new PlanExecute strategy for a given goal."
  @spec new(String.t()) :: t()
  def new(goal) when is_binary(goal) do
    %__MODULE__{goal: goal, phase: :survey}
  end

  # --- Phase Management ---

  @doc "Get the current phase."
  @spec phase(t()) :: phase()
  def phase(%__MODULE__{phase: p}), do: p

  @doc "Advance from survey to execute. Requires a plan to be set."
  @spec begin_execution(t()) :: t()
  def begin_execution(%__MODULE__{phase: :survey, plan: plan} = state) when plan != [] do
    %{state | phase: :execute, current_step_index: 0}
  end

  @doc "Advance from execute to verify."
  @spec begin_verification(t()) :: t()
  def begin_verification(%__MODULE__{phase: :execute} = state) do
    %{state | phase: :verify}
  end

  @doc "Mark the strategy as done."
  @spec finish(t()) :: t()
  def finish(%__MODULE__{} = state) do
    %{state | phase: :done}
  end

  # --- Plan Management ---

  @doc "Set the execution plan (list of steps). Call after survey."
  @spec set_plan(t(), [map()]) :: t()
  def set_plan(%__MODULE__{} = state, steps) when is_list(steps) do
    normalized =
      Enum.map(steps, fn step ->
        %{
          id: step[:id] || "step-#{System.unique_integer([:positive])}",
          task: step[:task] || step["task"] || "",
          status: :pending,
          files: step[:files] || step["files"] || [],
          lines: step[:lines] || step["lines"],
          result: nil
        }
      end)

    %{state | plan: normalized}
  end

  @doc "Set the survey result (the agent's analysis of the codebase)."
  @spec set_survey_result(t(), String.t()) :: t()
  def set_survey_result(%__MODULE__{} = state, result) when is_binary(result) do
    %{state | survey_result: result}
  end

  @doc "Set the verify result."
  @spec set_verify_result(t(), String.t()) :: t()
  def set_verify_result(%__MODULE__{} = state, result) when is_binary(result) do
    %{state | verify_result: result}
  end

  # --- Step Management ---

  @doc "Get the current step (or nil if all done)."
  @spec current_step(t()) :: step() | nil
  def current_step(%__MODULE__{plan: plan, current_step_index: idx}) do
    Enum.at(plan, idx)
  end

  @doc "Mark the current step as done and advance."
  @spec complete_step(t(), String.t()) :: t()
  def complete_step(%__MODULE__{plan: plan, current_step_index: idx} = state, result \\ "") do
    updated_plan =
      List.update_at(plan, idx, fn step ->
        %{step | status: :done, result: result}
      end)

    %{state | plan: updated_plan, current_step_index: idx + 1}
  end

  @doc "Mark the current step as failed and record the error."
  @spec fail_step(t(), String.t()) :: t()
  def fail_step(%__MODULE__{plan: plan, current_step_index: idx} = state, error) do
    updated_plan =
      List.update_at(plan, idx, fn step ->
        %{step | status: :failed, result: error}
      end)

    %{state | plan: updated_plan, current_step_index: idx + 1, errors: [error | state.errors]}
  end

  # --- Queries ---

  @doc "Are all steps complete (done, failed, or skipped)?"
  @spec all_steps_complete?(t()) :: boolean()
  def all_steps_complete?(%__MODULE__{plan: plan, current_step_index: idx}) do
    idx >= length(plan)
  end

  @doc "How many steps are done?"
  @spec steps_done(t()) :: non_neg_integer()
  def steps_done(%__MODULE__{plan: plan}) do
    Enum.count(plan, &(&1.status == :done))
  end

  @doc "How many steps total?"
  @spec steps_total(t()) :: non_neg_integer()
  def steps_total(%__MODULE__{plan: plan}), do: length(plan)

  @doc "Summary of progress."
  @spec progress(t()) :: String.t()
  def progress(%__MODULE__{} = state) do
    "#{state.phase} — #{steps_done(state)}/#{steps_total(state)} steps" <>
      if(state.errors == [], do: "", else: " (#{length(state.errors)} errors)")
  end
end
