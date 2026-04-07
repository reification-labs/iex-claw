# Contract tests for Tools.* return values.
#
# All Tools.* public functions MUST return {:ok, _} | {:error, _}.
# Bare values (lists, maps, strings) cause case-clause crashes in the
# agent loop's tool-result formatter.
#
# Run: elixir projects/iex-claw/test/tool_contract_test.exs

Code.require_file(Path.expand("../agents/code/code.exs", __DIR__))

ExUnit.start(autorun: false)

defmodule ToolContractTest do
  use ExUnit.Case, async: false

  describe "Tools.Messages return contract" do
    test "read_inbox returns {:ok, list}" do
      result = Tools.Messages.read_inbox()
      assert match?({:ok, _}, result)
      {:ok, value} = result
      assert is_list(value)
    end

    test "read_message returns {:ok, _} or {:error, _}" do
      assert match?({:error, _}, Tools.Messages.read_message("nonexistent-msg"))
    end

    test "send_message returns {:ok, _} or {:error, _}" do
      workspace = Path.expand("..", __DIR__)
      File.cd!(workspace)

      result =
        Tools.Messages.send_message(
          "code",
          "contract-test",
          [%{"kind" => "text", "text" => "hi"}]
        )

      assert match?({:ok, _}, result)

      # cleanup
      {:ok, env} = result
      File.rm(Path.join([workspace, "messages/inbox/code", env["id"] <> ".msg.json"]))
    end
  end

  describe "Tools.FileSystem return contract" do
    test "read_file returns {:ok, _} or {:error, _}" do
      workspace = Path.expand("..", __DIR__)
      File.cd!(workspace)
      assert match?({:ok, _}, Tools.FileSystem.read_file("MESSAGES.md"))
      assert match?({:error, _}, Tools.FileSystem.read_file("/etc/passwd"))
    end

    test "read_file_raw returns {:ok, _} or {:error, _}" do
      workspace = Path.expand("..", __DIR__)
      File.cd!(workspace)
      assert match?({:ok, _}, Tools.FileSystem.read_file_raw("MESSAGES.md"))
    end

    test "list_dir returns {:ok, _} or {:error, _}" do
      workspace = Path.expand("..", __DIR__)
      File.cd!(workspace)
      assert match?({:ok, _}, Tools.FileSystem.list_dir("agents"))
    end

    test "file_size returns {:ok, _} or {:error, _}" do
      workspace = Path.expand("..", __DIR__)
      File.cd!(workspace)
      assert match?({:ok, _}, Tools.FileSystem.file_size("MESSAGES.md"))
    end
  end
end

ExUnit.run()
