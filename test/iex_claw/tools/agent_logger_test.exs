defmodule IExClaw.Tools.AgentLoggerTest do
  use ExUnit.Case, async: true

  alias IExClaw.Tools.AgentLogger

  setup do
    workplace =
      Path.join(System.tmp_dir!(), "iex_claw_agentlog_#{System.unique_integer([:positive])}")

    log_dir = Path.join(workplace, "logs")
    File.mkdir_p!(workplace)
    on_exit(fn -> File.rm_rf!(workplace) end)
    {:ok, workplace: workplace, log_dir: log_dir}
  end

  describe "log/4" do
    test "writes per-tick file AND appends to growth.md", %{workplace: wp, log_dir: log_dir} do
      assert {:ok, msg} = AgentLogger.log("code", "first breath", log_dir, wp)
      assert msg =~ "Logged to"

      rolling = Path.join(log_dir, "growth.md")
      assert File.exists?(rolling)
      assert File.read!(rolling) =~ "code: first breath"
    end

    test "appends successive calls to growth.md", %{workplace: wp, log_dir: log_dir} do
      assert {:ok, _} = AgentLogger.log("code", "line one", log_dir, wp)
      assert {:ok, _} = AgentLogger.log("code", "line two", log_dir, wp)

      rolling = File.read!(Path.join(log_dir, "growth.md"))
      assert rolling =~ "line one"
      assert rolling =~ "line two"
    end

    test "creates the log dir on demand", %{workplace: wp, log_dir: log_dir} do
      refute File.dir?(log_dir)
      assert {:ok, _} = AgentLogger.log("goal", "awake", log_dir, wp)
      assert File.dir?(log_dir)
    end

    test "refuses to write outside the workplace", %{log_dir: log_dir} do
      other =
        Path.join(System.tmp_dir!(), "iex_claw_log_other_#{System.unique_integer([:positive])}")

      File.mkdir_p!(other)

      assert {:error, reason} = AgentLogger.log("code", "escape attempt", log_dir, other)
      assert reason =~ "Scope violation"
    end
  end
end
