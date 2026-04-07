defmodule IExClaw.Tools.EditFileTest do
  use ExUnit.Case, async: true

  alias IExClaw.Tools.EditFile

  setup do
    workplace = Path.join(System.tmp_dir!(), "iex_claw_edit_#{System.unique_integer([:positive])}")
    File.mkdir_p!(workplace)
    on_exit(fn -> File.rm_rf!(workplace) end)
    {:ok, workplace: workplace}
  end

  defp seed(wp, content) do
    path = Path.join(wp, "target.md")
    File.write!(path, content)
    path
  end

  describe "edit/3" do
    test "applies a single unique edit", %{workplace: wp} do
      path = seed(wp, "hello world\nkeep me\n")

      assert {:ok, msg} =
               EditFile.edit(path, wp, [%{"old_text" => "hello", "new_text" => "hi"}])

      assert msg =~ "Applied 1 edit(s)"
      assert File.read!(path) == "hi world\nkeep me\n"
    end

    test "accepts atom keys as well as string keys", %{workplace: wp} do
      path = seed(wp, "alpha beta gamma")

      assert {:ok, _} =
               EditFile.edit(path, wp, [%{old_text: "beta", new_text: "BETA"}])

      assert File.read!(path) == "alpha BETA gamma"
    end

    test "applies multiple edits atomically", %{workplace: wp} do
      path = seed(wp, "foo\nbar\nbaz\n")

      assert {:ok, _} =
               EditFile.edit(path, wp, [
                 %{"old_text" => "foo", "new_text" => "FOO"},
                 %{"old_text" => "baz", "new_text" => "BAZ"}
               ])

      assert File.read!(path) == "FOO\nbar\nBAZ\n"
    end

    test "refuses when old_text is not present (validates before writing)", %{workplace: wp} do
      original = "unchanged content"
      path = seed(wp, original)

      assert {:error, msg} =
               EditFile.edit(path, wp, [%{"old_text" => "missing", "new_text" => "x"}])

      assert msg =~ "oldText not found"
      assert File.read!(path) == original
    end

    test "refuses when old_text appears multiple times", %{workplace: wp} do
      original = "repeat\nrepeat\nrepeat\n"
      path = seed(wp, original)

      assert {:error, msg} =
               EditFile.edit(path, wp, [%{"old_text" => "repeat", "new_text" => "x"}])

      assert msg =~ "appears 3 times"
      assert File.read!(path) == original
    end

    test "validates all edits before applying any (atomicity)", %{workplace: wp} do
      original = "ok line\nduplicate\nduplicate\n"
      path = seed(wp, original)

      # First edit is valid (unique), second is invalid (duplicate).
      # Neither should apply.
      assert {:error, msg} =
               EditFile.edit(path, wp, [
                 %{"old_text" => "ok line", "new_text" => "OK LINE"},
                 %{"old_text" => "duplicate", "new_text" => "dup"}
               ])

      assert msg =~ "appears 2 times"
      assert File.read!(path) == original
    end

    test "refuses paths outside workplace", %{workplace: wp} do
      assert {:error, msg} =
               EditFile.edit("/etc/hosts", wp, [%{"old_text" => "a", "new_text" => "b"}])

      assert msg =~ "Scope violation"
    end
  end
end
