defmodule IExClaw.Tools.ScopeGuardTest do
  use ExUnit.Case, async: true

  alias IExClaw.Tools.ScopeGuard

  @workplace "/tmp/iex_claw_scope_test"

  describe "validate/2" do
    test "accepts paths inside workplace" do
      assert {:ok, expanded} = ScopeGuard.validate("#{@workplace}/foo.md", @workplace)
      assert expanded == "#{@workplace}/foo.md"
    end

    test "accepts the workplace directory itself" do
      workplace = @workplace
      assert {:ok, ^workplace} = ScopeGuard.validate(workplace, workplace)
    end

    test "rejects paths outside workplace" do
      assert {:error, msg} = ScopeGuard.validate("/etc/passwd", @workplace)
      assert msg =~ "Scope violation"
      assert msg =~ "/etc/passwd"
    end

    test "rejects the classic prefix-trick escape (workplace-evil)" do
      assert {:error, _} = ScopeGuard.validate("#{@workplace}-evil/x", @workplace)
    end

    test "rejects ../ traversal after expansion" do
      assert {:error, _} = ScopeGuard.validate("#{@workplace}/../../etc/passwd", @workplace)
    end

    test "expands relative paths correctly" do
      cwd = File.cwd!()
      assert {:ok, expanded} = ScopeGuard.validate("foo.md", cwd)
      assert expanded == Path.join(cwd, "foo.md")
    end
  end

  describe "validate!/2" do
    test "returns expanded path on success" do
      assert ScopeGuard.validate!("#{@workplace}/x.md", @workplace) == "#{@workplace}/x.md"
    end

    test "raises on scope violation" do
      assert_raise RuntimeError, ~r/Scope violation/, fn ->
        ScopeGuard.validate!("/etc/passwd", @workplace)
      end
    end
  end
end
