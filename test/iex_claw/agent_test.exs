defmodule IExClaw.AgentTest do
  use ExUnit.Case, async: true

  alias IExClaw.Agent

  describe "load_soul_docs/2" do
    setup do
      dir = Path.join(System.tmp_dir!(), "iex_claw_agent_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "SOUL.md"), "I am Code.")
      File.write!(Path.join(dir, "IDENTITY.md"), "Name: Code")
      File.write!(Path.join(dir, "PHILOSOPHY.md"), "Boundaries are love.")
      on_exit(fn -> File.rm_rf!(dir) end)
      {:ok, dir: dir}
    end

    test "loads base soul docs from directory", %{dir: dir} do
      result = Agent.load_soul_docs(dir)
      assert result =~ "## SOUL.md"
      assert result =~ "I am Code."
      assert result =~ "## IDENTITY.md"
      assert result =~ "Name: Code"
      assert result =~ "## PHILOSOPHY.md"
      assert result =~ "Boundaries are love."
    end

    test "includes extra soul files", %{dir: dir} do
      extra = Path.join(dir, "GOAL.md")
      File.write!(extra, "The North Star.")
      result = Agent.load_soul_docs(dir, [{extra, "GOAL.md (THE NORTH STAR)"}])
      assert result =~ "## GOAL.md (THE NORTH STAR)"
      assert result =~ "The North Star."
    end

    test "handles missing files gracefully", %{dir: dir} do
      File.rm!(Path.join(dir, "PHILOSOPHY.md"))
      result = Agent.load_soul_docs(dir)
      assert result =~ "(not found at"
    end
  end

  describe "append_message/3" do
    test "appends a message to state" do
      state = %{messages: [%{"role" => "system", "content" => "hi"}]}
      new_state = Agent.append_message(state, "user", "hello")
      assert length(new_state.messages) == 2
      assert List.last(new_state.messages) == %{"role" => "user", "content" => "hello"}
    end
  end

  describe "extract_summary/1" do
    test "extracts the last assistant message" do
      state = %{
        messages: [
          %{"role" => "system", "content" => "sys"},
          %{"role" => "user", "content" => "task"},
          %{"role" => "assistant", "content" => "first reply"},
          %{"role" => "user", "content" => "more"},
          %{"role" => "assistant", "content" => "final summary"}
        ]
      }

      assert Agent.extract_summary(state) == "final summary"
    end

    test "returns default when no assistant messages" do
      state = %{messages: [%{"role" => "system", "content" => "sys"}]}
      assert Agent.extract_summary(state) == "No summary generated"
    end
  end
end
