# Standalone test for Tools.FileSystem.read_file/3 slicing behavior and
# the read_file_raw/1 internal helper.
#
# Run with:
#   elixir projects/iex-claw/test/read_file_slicing_test.exs
#
# Covers the bug from 2026-04-05: edit_file was calling the banner-prefixed
# read_file internally, causing file corruption when writing "original" back.
# The fix: edit_file now calls read_file_raw/1 which returns exact bytes.

Code.require_file(Path.expand("../agents/code/code.exs", __DIR__))

ExUnit.start(autorun: false)

defmodule ReadFileSlicingTest do
  use ExUnit.Case, async: false

  @workplace Path.expand("..", __DIR__)
  @fixture_path Path.join(@workplace, "test/tmp/read_file_fixture.txt")

  setup do
    File.mkdir_p!(Path.dirname(@fixture_path))
    # 20KB fixture: repeated 1KB blocks labeled A..T
    content =
      for letter <- ?A..?T, into: "" do
        String.duplicate(<<letter>>, 1024)
      end

    File.write!(@fixture_path, content)
    on_exit(fn -> File.rm(@fixture_path) end)
    {:ok, fixture: @fixture_path, content: content, total: byte_size(content)}
  end

  describe "read_file_raw/1 (internal)" do
    test "returns exact full bytes with no banner", %{fixture: path, content: content} do
      assert {:ok, raw} = Tools.FileSystem.read_file_raw(path)
      assert raw == content
      refute String.contains?(raw, "[read_file banner]")
    end

    test "scope-guarded: refuses paths outside workplace" do
      assert {:error, msg} = Tools.FileSystem.read_file_raw("/etc/passwd")
      assert msg =~ "Scope violation"
    end
  end

  describe "read_file/3 (LLM-facing, sliced + banner)" do
    test "default call returns banner + first 8000 bytes", %{fixture: path, total: total} do
      assert {:ok, result} = Tools.FileSystem.read_file(path)
      assert String.starts_with?(result, "[read_file banner]")
      assert result =~ "total=#{total}"
      assert result =~ "offset=0"
      assert result =~ "returned=8000"
      assert result =~ "next_offset=8000"

      [_banner, body] = String.split(result, "\n", parts: 2)
      assert byte_size(body) == 8000
      assert String.starts_with?(body, String.duplicate("A", 1024))
    end

    test "offset lets the caller page forward", %{fixture: path} do
      assert {:ok, r1} = Tools.FileSystem.read_file(path, 0, 4096)
      assert r1 =~ "returned=4096"
      assert r1 =~ "next_offset=4096"

      assert {:ok, r2} = Tools.FileSystem.read_file(path, 4096, 4096)
      assert r2 =~ "offset=4096"
      assert r2 =~ "returned=4096"
      assert r2 =~ "next_offset=8192"

      [_, body2] = String.split(r2, "\n", parts: 2)
      # bytes 4096..8191 = all E block (bytes 4096..5119) + F (5120..6143) etc.
      # byte 4096 is 'E' (0-indexed: A=0-1023, B=1024-2047, C=2048-3071, D=3072-4095, E=4096-5119)
      assert String.starts_with?(body2, "E")
    end

    test "limit=0 returns the whole file", %{fixture: path, total: total} do
      assert {:ok, result} = Tools.FileSystem.read_file(path, 0, 0)
      assert result =~ "returned=#{total}"
      assert result =~ "(end of file)"

      [_, body] = String.split(result, "\n", parts: 2)
      assert byte_size(body) == total
    end

    test "offset past EOF returns empty body with banner", %{fixture: path, total: total} do
      assert {:ok, result} = Tools.FileSystem.read_file(path, total + 100, 1000)
      assert result =~ "offset past EOF"
      assert result =~ "returned=0"
    end

    test "end of file signaled correctly near EOF", %{fixture: path, total: total} do
      assert {:ok, result} = Tools.FileSystem.read_file(path, total - 100, 1000)
      assert result =~ "returned=100"
      assert result =~ "(end of file)"
      refute result =~ "next_offset="
    end

    test "nil offset/limit behaves like defaults", %{fixture: path} do
      assert {:ok, result} = Tools.FileSystem.read_file(path, nil, nil)
      assert result =~ "returned=8000"
    end
  end

  describe "edit_file regression: MUST use raw read, not banner read" do
    test "editing a large file does not corrupt or truncate it", %{fixture: path} do
      # This is the regression test for the 2026-04-05 bug. Before the fix,
      # edit_file would call read_file (with banner + 8KB truncation) to get
      # the 'original' content, replace, then write that truncated blob back
      # -- obliterating the rest of the file and injecting a banner line.
      original_size = File.stat!(path).size
      assert original_size > 8000

      # A unique anchor that appears exactly once (first 1024 'A' bytes).
      # Use a distinctive slice we know the location of.
      anchor =
        String.duplicate("A", 1024) <> String.duplicate("B", 10)

      assert {:ok, _msg} =
               Tools.EditFile.edit(path, [
                 %{"old_text" => anchor, "new_text" => anchor <> "_EDITED"}
               ])

      new_content = File.read!(path)
      new_size = byte_size(new_content)

      # Size should grow by exactly the suffix length, NOT shrink to 8KB.
      assert new_size == original_size + byte_size("_EDITED")

      # No banner text should ever land inside the file.
      refute String.contains?(new_content, "[read_file banner]")

      # The tail of the file should still contain the T block (last 1024 bytes).
      assert String.ends_with?(new_content, String.duplicate("T", 1024))
    end

    test "editing preserves bytes past 8KB (no truncation)", %{fixture: path} do
      # The smoking gun: replace something AFTER byte 8000 and verify the
      # content past 8000 still exists and is not clobbered.
      anchor = String.duplicate("T", 1024)
      refute anchor == String.duplicate("A", 1024)

      assert {:ok, _msg} =
               Tools.EditFile.edit(path, [
                 %{"old_text" => anchor, "new_text" => "T_REPLACED"}
               ])

      new_content = File.read!(path)
      assert byte_size(new_content) > 8000
      assert String.contains?(new_content, "T_REPLACED")
      assert String.contains?(new_content, String.duplicate("S", 1024))
      refute String.contains?(new_content, "[read_file banner]")
    end
  end
end

ExUnit.run()
