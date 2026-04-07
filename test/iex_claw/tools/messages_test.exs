defmodule IExClaw.Tools.MessagesTest do
  use ExUnit.Case, async: true

  alias IExClaw.Tools.Messages

  setup do
    workplace =
      Path.join(System.tmp_dir!(), "iex_claw_msgs_#{System.unique_integer([:positive])}")

    inbox_base = Path.join(workplace, "messages/inbox")
    File.mkdir_p!(inbox_base)
    on_exit(fn -> File.rm_rf!(workplace) end)
    {:ok, workplace: workplace, inbox_base: inbox_base}
  end

  describe "read_inbox/2" do
    test "returns empty list when inbox dir is missing", %{inbox_base: ib} do
      assert {:ok, []} = Messages.read_inbox("nobody", ib)
    end

    test "lists messages newest-first and summarizes parts", %{inbox_base: ib} do
      File.mkdir_p!(Path.join(ib, "code"))

      env_a = %{
        "id" => "msg-2026-04-05-120000-0001",
        "from" => "goal",
        "to" => "code",
        "in_reply_to" => nil,
        "task_id" => "t1",
        "timestamp" => "2026-04-05T12:00:00Z",
        "expects_response" => false,
        "parts" => [%{"kind" => "text", "text" => "first message"}]
      }

      env_b = %{
        env_a
        | "id" => "msg-2026-04-05-130000-0002",
          "parts" => [%{"kind" => "text", "text" => "second message"}, %{"kind" => "verdict"}]
      }

      File.write!(
        Path.join(ib, "code/msg-2026-04-05-120000-0001.msg.json"),
        Jason.encode!(env_a)
      )

      File.write!(
        Path.join(ib, "code/msg-2026-04-05-130000-0002.msg.json"),
        Jason.encode!(env_b)
      )

      assert {:ok, [newest, oldest]} = Messages.read_inbox("code", ib)
      assert newest.id == "msg-2026-04-05-130000-0002"
      assert oldest.id == "msg-2026-04-05-120000-0001"
      assert newest.parts_summary == ["second message", "[verdict]"]
    end

    test "tolerates malformed json files", %{inbox_base: ib} do
      File.mkdir_p!(Path.join(ib, "code"))
      File.write!(Path.join(ib, "code/msg-broken.msg.json"), "not json")
      assert {:ok, [summary]} = Messages.read_inbox("code", ib)
      assert summary.parts_summary == ["[malformed]"]
    end

    test "ignores non-.msg.json files", %{inbox_base: ib} do
      File.mkdir_p!(Path.join(ib, "code"))
      File.write!(Path.join(ib, "code/notes.txt"), "side note")
      assert {:ok, []} = Messages.read_inbox("code", ib)
    end
  end

  describe "read_message/3" do
    test "reads a message with or without extension", %{inbox_base: ib} do
      File.mkdir_p!(Path.join(ib, "code"))
      id = "msg-2026-04-05-110000-0001"
      envelope = %{"id" => id, "parts" => [%{"kind" => "text", "text" => "hi"}]}
      File.write!(Path.join(ib, "code/#{id}.msg.json"), Jason.encode!(envelope))

      assert {:ok, got} = Messages.read_message("code", id, ib)
      assert got["id"] == id
      assert {:ok, ^got} = Messages.read_message("code", "#{id}.msg.json", ib)
    end

    test "errors when message is missing", %{inbox_base: ib} do
      assert {:error, msg} = Messages.read_message("code", "msg-nope", ib)
      assert msg =~ "Message not found"
    end
  end

  describe "send_message/7" do
    test "writes an envelope to the recipient inbox", %{workplace: wp, inbox_base: ib} do
      parts = [%{"kind" => "text", "text" => "proposal draft"}]

      assert {:ok, env} =
               Messages.send_message("code", "goal", "task-x", parts, ib, wp, expects_response: true)

      assert env["from"] == "code"
      assert env["to"] == "goal"
      assert env["expects_response"] == true
      assert env["task_id"] == "task-x"
      assert env["in_reply_to"] == nil
      assert is_binary(env["id"])

      filename = "#{env["id"]}.msg.json"
      path = Path.join([ib, "goal", filename])
      assert File.exists?(path)

      decoded = path |> File.read!() |> Jason.decode!()
      assert decoded["id"] == env["id"]
    end

    test "creates the recipient inbox dir if missing", %{workplace: wp, inbox_base: ib} do
      refute File.dir?(Path.join(ib, "fresh"))

      assert {:ok, _} =
               Messages.send_message("code", "fresh", "t", [], ib, wp)

      assert File.dir?(Path.join(ib, "fresh"))
    end

    test "refuses to write outside the workplace", %{inbox_base: ib} do
      other = Path.join(System.tmp_dir!(), "iex_claw_other_#{System.unique_integer([:positive])}")
      File.mkdir_p!(other)

      # inbox_base lives OUTSIDE the workplace we pass in
      assert {:error, msg} = Messages.send_message("code", "goal", "t", [], ib, other)
      assert msg =~ "Scope violation"
    end

    test "threads via in_reply_to", %{workplace: wp, inbox_base: ib} do
      assert {:ok, env} =
               Messages.send_message("code", "goal", "task-x", [], ib, wp, in_reply_to: "msg-parent-0001")

      assert env["in_reply_to"] == "msg-parent-0001"
    end
  end
end
