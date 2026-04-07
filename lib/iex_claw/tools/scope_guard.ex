defmodule IExClaw.Tools.ScopeGuard do
  @moduledoc """
  Path boundary enforcement. Every agent declares its workplace; ScopeGuard
  refuses paths that escape it.

  "Boundaries are love." — Code

  Unlike the original inline version in code.exs, this module is parametric:
  the workplace is passed at call time, not compiled in. That makes ScopeGuard
  reusable by any agent with any scope.
  """

  @doc """
  Validate that `path` (after expansion) lives inside `workplace`.

  Returns `{:ok, expanded_path}` or `{:error, reason}`.
  """
  @spec validate(Path.t(), Path.t()) :: {:ok, Path.t()} | {:error, String.t()}
  def validate(path, workplace) when is_binary(path) and is_binary(workplace) do
    expanded = Path.expand(path)
    workplace = Path.expand(workplace)

    if inside?(expanded, workplace) do
      {:ok, expanded}
    else
      {:error,
       "Scope violation: #{path} resolves to #{expanded}, " <>
         "which is outside workplace (#{workplace})."}
    end
  end

  @doc """
  Validate or raise. Convenience wrapper; prefer `validate/2` in tools.
  """
  @spec validate!(Path.t(), Path.t()) :: Path.t()
  def validate!(path, workplace) do
    case validate(path, workplace) do
      {:ok, expanded} -> expanded
      {:error, reason} -> raise reason
    end
  end

  # A path is inside workplace if it equals it or begins with workplace<sep>.
  # This avoids the classic "/foo/bar-evil" prefix-match bug.
  defp inside?(path, workplace) do
    path == workplace or String.starts_with?(path, workplace <> "/")
  end
end
