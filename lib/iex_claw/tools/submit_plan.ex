defmodule IExClaw.Tools.SubmitPlan do
  @moduledoc """
  The exit gate from survey mode.

  This tool accepts a JSON plan (array of steps) and validates it.
  If the plan is valid, the survey phase is complete and the contract
  can advance to execute mode.

  This tool exists so that "output a plan" is a TOOL CALL, not a prose
  message. The agent physically cannot exit survey mode without calling
  this tool with valid JSON. No tool call → no transition → budget
  exhausted → restart.

  "The phone is in another room."
  """

  @type step :: %{String.t() => term()}
  @type result :: {:ok, [step()]} | {:error, String.t()}

  @doc """
  Submit a plan as a JSON string.

  Validates:
  - Plan is valid JSON
  - Plan is a list of at least 1 step
  - Each step has "id" and "task" fields

  Returns `{:ok, parsed_steps}` or `{:error, reason}`.
  """
  @spec submit(String.t()) :: result()
  def submit(plan_json) when is_binary(plan_json) do
    with {:ok, parsed} <- Jason.decode(plan_json),
         :ok <- validate_plan(parsed) do
      {:ok, parsed}
    else
      {:error, %Jason.DecodeError{} = e} ->
        {:error, "Invalid JSON: #{Exception.message(e)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_plan(plan) when is_list(plan) and length(plan) > 0 do
    errors =
      plan
      |> Enum.with_index()
      |> Enum.flat_map(fn {step, idx} ->
        cond do
          not is_map(step) -> ["Step #{idx}: not a map"]
          not Map.has_key?(step, "id") -> ["Step #{idx}: missing 'id'"]
          not Map.has_key?(step, "task") -> ["Step #{idx}: missing 'task'"]
          true -> []
        end
      end)

    if errors == [], do: :ok, else: {:error, "Plan validation failed: #{Enum.join(errors, "; ")}"}
  end

  defp validate_plan([]), do: {:error, "Plan is empty — must have at least one step"}
  defp validate_plan(_), do: {:error, "Plan must be a JSON array of step objects"}
end
