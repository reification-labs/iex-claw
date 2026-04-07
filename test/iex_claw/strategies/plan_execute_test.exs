defmodule IExClaw.Strategies.PlanExecuteTest do
  use ExUnit.Case, async: true

  alias IExClaw.Strategies.PlanExecute

  describe "lifecycle" do
    test "starts in survey phase" do
      state = PlanExecute.new("refactor code.exs")
      assert PlanExecute.phase(state) == :survey
      assert PlanExecute.steps_total(state) == 0
    end

    test "transitions survey → execute → verify → done" do
      state =
        PlanExecute.new("refactor")
        |> PlanExecute.set_plan([%{task: "step 1"}, %{task: "step 2"}])
        |> PlanExecute.begin_execution()

      assert PlanExecute.phase(state) == :execute

      state =
        state
        |> PlanExecute.complete_step("done 1")
        |> PlanExecute.complete_step("done 2")
        |> PlanExecute.begin_verification()

      assert PlanExecute.phase(state) == :verify

      state = PlanExecute.finish(state)
      assert PlanExecute.phase(state) == :done
    end
  end

  describe "plan management" do
    test "set_plan normalizes steps" do
      state =
        PlanExecute.new("refactor")
        |> PlanExecute.set_plan([
          %{task: "replace ToolRegistry", files: ["code.exs"], lines: "156-270"},
          %{task: "replace agent_loop", files: ["code.exs"]}
        ])

      assert PlanExecute.steps_total(state) == 2
      step = PlanExecute.current_step(state)
      assert step.task == "replace ToolRegistry"
      assert step.status == :pending
      assert step.files == ["code.exs"]
      assert step.lines == "156-270"
    end
  end

  describe "step execution" do
    setup do
      state =
        PlanExecute.new("test")
        |> PlanExecute.set_plan([%{task: "a"}, %{task: "b"}, %{task: "c"}])
        |> PlanExecute.begin_execution()

      {:ok, state: state}
    end

    test "current_step returns the first pending step", %{state: state} do
      assert PlanExecute.current_step(state).task == "a"
    end

    test "complete_step advances to next", %{state: state} do
      state = PlanExecute.complete_step(state, "did a")
      assert PlanExecute.current_step(state).task == "b"
      assert PlanExecute.steps_done(state) == 1
    end

    test "fail_step records error and advances", %{state: state} do
      state = PlanExecute.fail_step(state, "boom")
      assert PlanExecute.current_step(state).task == "b"
      assert length(state.errors) == 1
    end

    test "all_steps_complete? after completing all", %{state: state} do
      state =
        state
        |> PlanExecute.complete_step("a")
        |> PlanExecute.complete_step("b")
        |> PlanExecute.complete_step("c")

      assert PlanExecute.all_steps_complete?(state)
      assert PlanExecute.current_step(state) == nil
    end

    test "progress string", %{state: state} do
      assert PlanExecute.progress(state) == "execute — 0/3 steps"

      state = PlanExecute.complete_step(state, "a")
      assert PlanExecute.progress(state) == "execute — 1/3 steps"

      state = PlanExecute.fail_step(state, "err")
      assert PlanExecute.progress(state) =~ "1 errors"
    end
  end

  describe "survey result" do
    test "stores survey analysis" do
      state =
        PlanExecute.new("refactor")
        |> PlanExecute.set_survey_result("Found 3 sections to change")

      assert state.survey_result == "Found 3 sections to change"
    end
  end
end
