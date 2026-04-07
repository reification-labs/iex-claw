defmodule IExClaw.Tools.FileSystemTest do
  use ExUnit.Case, async: true

  alias IExClaw.Tools.FileSystem

  setup do
    workplace = Path.join(System.tmp_dir!(), "iex_claw_fs_#{System.unique_integer([:positive])}")
    File.mkdir_p!(workplace)
    on_exit(fn -> File.rm_rf!(workplace) end)
    {:ok, workplace: workplace}
  end

  describe "read_file_raw/2" do
    test "reads a file inside workplace", %{workplace: wp} do
      File.write!(Path.join(wp, "hi.txt"), "hello")
      assert {:ok, "hello"} = FileSystem.read_file_raw(Path.join(wp, "hi.txt"), wp)
    end

    test "refuses paths outside workplace", %{workplace: wp} do
      assert {:error, msg} = FileSystem.read_file_raw("/etc/passwd", wp)
      assert msg =~ "Scope violation"
    end

    test "errors clearly on missing file", %{workplace: wp} do
      assert {:error, msg} = FileSystem.read_file_raw(Path.join(wp, "nope.txt"), wp)
      assert msg =~ "Failed to read"
    end
  end

  describe "read_file/4 with banner + slicing" do
    test "returns whole file with end-of-file banner", %{workplace: wp} do
      path = Path.join(wp, "x.txt")
      File.write!(path, "abc")
      assert {:ok, result} = FileSystem.read_file(path, wp, 0, 0)
      assert result =~ "total=3 offset=0 returned=3 (end of file)"
      assert String.ends_with?(result, "abc")
    end

    test "slices with next_offset hint", %{workplace: wp} do
      path = Path.join(wp, "x.txt")
      File.write!(path, String.duplicate("x", 100))
      assert {:ok, result} = FileSystem.read_file(path, wp, 0, 10)
      assert result =~ "returned=10 next_offset=10"
    end

    test "returns offset-past-EOF banner", %{workplace: wp} do
      path = Path.join(wp, "x.txt")
      File.write!(path, "abc")
      assert {:ok, result} = FileSystem.read_file(path, wp, 99, 10)
      assert result =~ "returned=0 (offset past EOF)"
    end
  end

  describe "write_file/4" do
    test "creates a new file", %{workplace: wp} do
      path = Path.join(wp, "sub/nested.md")
      assert {:ok, _} = FileSystem.write_file(path, wp, "hi", false)
      assert File.read!(path) == "hi"
    end

    test "refuses to clobber without overwrite", %{workplace: wp} do
      path = Path.join(wp, "x.md")
      File.write!(path, "original")
      assert {:error, msg} = FileSystem.write_file(path, wp, "new", false)
      assert msg =~ "File exists"
      assert File.read!(path) == "original"
    end

    test "overwrites when explicitly allowed", %{workplace: wp} do
      path = Path.join(wp, "x.md")
      File.write!(path, "original")
      assert {:ok, _} = FileSystem.write_file(path, wp, "new", true)
      assert File.read!(path) == "new"
    end

    test "refuses paths outside workplace", %{workplace: wp} do
      assert {:error, _} = FileSystem.write_file("/tmp/escape.txt", wp, "no", false)
    end
  end

  describe "list_dir/2 and file_size/2" do
    test "lists sorted entries", %{workplace: wp} do
      File.write!(Path.join(wp, "b"), "")
      File.write!(Path.join(wp, "a"), "")
      assert {:ok, ["a", "b"]} = FileSystem.list_dir(wp, wp)
    end

    test "returns byte size", %{workplace: wp} do
      path = Path.join(wp, "x")
      File.write!(path, "12345")
      assert {:ok, 5} = FileSystem.file_size(path, wp)
    end
  end

  describe "backup/2" do
    test "creates a timestamped backup sibling", %{workplace: wp} do
      path = Path.join(wp, "x.md")
      File.write!(path, "contents")
      assert {:ok, msg} = FileSystem.backup(path, wp)
      assert msg =~ "Backed up to"

      [backup] = Path.wildcard(Path.join(wp, "x.md.backup.*"))
      assert File.read!(backup) == "contents"
    end

    test "refuses to backup missing file", %{workplace: wp} do
      assert {:error, msg} = FileSystem.backup(Path.join(wp, "nope"), wp)
      assert msg =~ "does not exist"
    end
  end
end
