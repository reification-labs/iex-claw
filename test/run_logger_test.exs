defmodule IExClaw.RunLoggerTest do
  use ExUnit.Case, async: true

  alias IExClaw.RunLogger

  @moduletag :tmp_dir
  setup %{tmp_dir: tmp_dir} do
    %{workplace: tmp_dir}
  end

  describe "generate_run_id/2" do
    test "produces agent-timestamp-slug format" do
      id = RunLogger.generate_run_id("code", "self surgery on ToolRegistry")
      assert id =~ ~r/^code-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}-self-surgery-on-toolregistry$/
    end

    test "defaults to 'run' slug" do
      id = RunLogger.generate_run_id("goal")
      assert id =~ ~r/^goal-.*-run$/
    end

    test "truncates long slugs" do
      long_input = String.duplicate("very long goal description ", 10)
      id = RunLogger.generate_run_id("code", long_input)
      # Agent (4) + dash + timestamp (~19) + dash + slug (max 40) = ~65 max
      assert byte_size(id) <= 70
    end
  end

  describe "emit/5" do
    test "appends JSONL to run file", %{workplace: wp} do
      run_id = "test-run-001"

      RunLogger.emit(run_id, wp, "tool_call", %{name: "read_file"}, %{agent: "code", model: "test"})
      RunLogger.emit(run_id, wp, "tool_result", %{name: "read_file", status: "ok"}, %{agent: "code", model: "test"})

      path = Path.join([wp, "logs/runs", "#{run_id}.events.jsonl"])
      assert File.exists?(path)

      lines = path |> File.read!() |> String.split("\n", trim: true)
      assert length(lines) == 2

      event1 = Jason.decode!(hd(lines))
      assert event1["event"] == "tool_call"
      assert event1["run_id"] == "test-run-001"
      assert event1["data"]["name"] == "read_file"
      assert event1["agent"] == "code"
      assert is_binary(event1["ts"])
    end

    test "includes context fields when present", %{workplace: wp} do
      RunLogger.emit("ctx-run", wp, "tool_call", %{name: "edit_file"}, %{
        agent: "code",
        model: "glm-5",
        phase: "execute",
        step_id: "step-2",
        budget_remaining: 7
      })

      path = Path.join([wp, "logs/runs", "ctx-run.events.jsonl"])
      event = path |> File.read!() |> String.trim() |> Jason.decode!()

      assert event["context"]["phase"] == "execute"
      assert event["context"]["step_id"] == "step-2"
      assert event["context"]["budget_remaining"] == 7
    end

    test "omits context key when no context fields", %{workplace: wp} do
      RunLogger.emit("no-ctx", wp, "llm_request", %{model: "test"}, %{agent: "code", model: "test"})

      path = Path.join([wp, "logs/runs", "no-ctx.events.jsonl"])
      event = path |> File.read!() |> String.trim() |> Jason.decode!()

      refute Map.has_key?(event, "context")
    end
  end

  describe "callback/3" do
    test "returns a function that emits with auto-incrementing seq", %{workplace: wp} do
      cb = RunLogger.callback("cb-run", wp, agent: "code", model: "glm-5")

      cb.("tool_call", %{name: "read_file"}, %{})
      cb.("tool_call", %{name: "edit_file"}, %{})
      cb.("tool_result", %{name: "edit_file"}, %{phase: "execute"})

      path = Path.join([wp, "logs/runs", "cb-run.events.jsonl"])
      lines = path |> File.read!() |> String.split("\n", trim: true) |> Enum.map(&Jason.decode!/1)

      assert length(lines) == 3
      assert Enum.map(lines, & &1["seq"]) == [1, 2, 3]
      assert Enum.at(lines, 0)["agent"] == "code"
      assert Enum.at(lines, 2)["context"]["phase"] == "execute"
    end
  end

  describe "noop/0" do
    test "returns a function that does nothing" do
      cb = RunLogger.noop()
      assert cb.("anything", %{}, %{}) == :ok
    end
  end
end
