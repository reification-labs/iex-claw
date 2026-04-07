defmodule IExClaw.ContractTest do
  use ExUnit.Case, async: true

  alias IExClaw.Contract
  alias IExClaw.Mode

  setup do
    modes = [
      Mode.new(:survey, tools: [:read_file, :submit_plan], output: :json_plan, next: :execute),
      Mode.new(:execute, tools: [:read_file, :edit_file], output: :step_result, next: :verify),
      Mode.new(:verify, tools: [:read_file, :file_size], output: :report, next: :done)
    ]

    contract =
      Contract.new(
        goal: "Rewire ToolRegistry",
        agent: "code",
        supervisor: "project",
        modes: modes
      )

    {:ok, contract: contract}
  end

  test "starts in pending, transitions to active", %{contract: c} do
    assert c.status == :pending
    {:ok, c} = Contract.start(c)
    assert c.status == :active
    assert c.attempts == 1
  end

  test "current_mode returns the first mode", %{contract: c} do
    {:ok, c} = Contract.start(c)
    mode = Contract.current_mode(c)
    assert mode.name == :survey
    assert :submit_plan in mode.tools
  end

  test "advance moves through modes", %{contract: c} do
    {:ok, c} = Contract.start(c)
    assert Contract.current_mode(c).name == :survey

    {:ok, c} = Contract.advance(c)
    assert Contract.current_mode(c).name == :execute

    {:ok, c} = Contract.advance(c)
    assert Contract.current_mode(c).name == :verify

    {:done, c} = Contract.advance(c)
    assert c.status == :completed
  end

  test "budget_exhausted restarts until max_attempts", %{contract: c} do
    {:ok, c} = Contract.start(c)

    {:restart, c} = Contract.budget_exhausted(c)
    assert c.attempts == 2
    assert c.status == :restarting

    {:restart, c} = Contract.budget_exhausted(c)
    assert c.attempts == 3

    {:failed, c} = Contract.budget_exhausted(c)
    assert c.status == :failed
  end

  test "checkpoint records and retrieves", %{contract: c} do
    assert Contract.last_checkpoint(c) == nil
    c = Contract.checkpoint(c, "abc123")
    assert Contract.last_checkpoint(c) == "abc123"
    c = Contract.checkpoint(c, "def456")
    assert Contract.last_checkpoint(c) == "def456"
  end

  test "summary includes key info", %{contract: c} do
    {:ok, c} = Contract.start(c)
    s = Contract.summary(c)
    assert s =~ "code"
    assert s =~ "project"
    assert s =~ "survey"
    assert s =~ "1/3"
  end
end
