defmodule IExClaw.Tools.SubmitPlanTest do
  use ExUnit.Case, async: true

  alias IExClaw.Tools.SubmitPlan

  test "accepts valid plan" do
    json = Jason.encode!([
      %{"id" => "step-1", "task" => "do thing"},
      %{"id" => "step-2", "task" => "do other thing"}
    ])

    assert {:ok, steps} = SubmitPlan.submit(json)
    assert length(steps) == 2
    assert hd(steps)["id"] == "step-1"
  end

  test "rejects empty plan" do
    assert {:error, msg} = SubmitPlan.submit("[]")
    assert msg =~ "empty"
  end

  test "rejects invalid JSON" do
    assert {:error, msg} = SubmitPlan.submit("not json at all")
    assert msg =~ "Invalid JSON"
  end

  test "rejects steps missing id" do
    json = Jason.encode!([%{"task" => "no id"}])
    assert {:error, msg} = SubmitPlan.submit(json)
    assert msg =~ "missing 'id'"
  end

  test "rejects steps missing task" do
    json = Jason.encode!([%{"id" => "step-1"}])
    assert {:error, msg} = SubmitPlan.submit(json)
    assert msg =~ "missing 'task'"
  end

  test "accepts steps with extra fields" do
    json = Jason.encode!([%{"id" => "step-1", "task" => "do thing", "files" => ["a.ex"], "lines" => "10-20"}])
    assert {:ok, [step]} = SubmitPlan.submit(json)
    assert step["files"] == ["a.ex"]
  end
end
