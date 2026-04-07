defmodule IExClaw.ModeTest do
  use ExUnit.Case, async: true

  alias IExClaw.Mode

  @full_tools %{
    "read_file" => {Mod, :read, "read", []},
    "write_file" => {Mod, :write, "write", []},
    "edit_file" => {Mod, :edit, "edit", []},
    "submit_plan" => {Mod, :plan, "plan", []},
    "list_dir" => {Mod, :list, "list", []}
  }

  test "new creates a mode with required fields" do
    mode = Mode.new(:survey, tools: [:read_file, :submit_plan], output: :json_plan)
    assert mode.name == :survey
    assert mode.tools == [:read_file, :submit_plan]
    assert mode.output == :json_plan
    assert mode.next == :done
  end

  test "filter_tools removes tools not in the mode" do
    mode = Mode.new(:survey, tools: [:read_file, :list_dir, :submit_plan], output: :json_plan)
    filtered = Mode.filter_tools(mode, @full_tools)

    assert filtered |> Map.keys() |> Enum.sort() == ["list_dir", "read_file", "submit_plan"]
    refute Map.has_key?(filtered, "write_file")
    refute Map.has_key?(filtered, "edit_file")
  end

  test "filter_tools with execute mode" do
    mode = Mode.new(:execute, tools: [:read_file, :edit_file], output: :step_result)
    filtered = Mode.filter_tools(mode, @full_tools)

    assert Map.has_key?(filtered, "read_file")
    assert Map.has_key?(filtered, "edit_file")
    refute Map.has_key?(filtered, "submit_plan")
  end
end
