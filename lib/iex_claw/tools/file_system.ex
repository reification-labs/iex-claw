defmodule IExClaw.Tools.FileSystem do
  @moduledoc """
  File operations guarded by `IExClaw.Tools.ScopeGuard`.

  All functions take a `workplace` argument declaring the agent's boundary.
  Every path is validated before the operation runs. "Show me what's there
  first" — read is always safe; write/backup require explicit intent.

  Extracted from agents/code/code.exs on 2026-04-05 as part of the
  "earn the substrate" molt.
  """

  alias IExClaw.Tools.ScopeGuard

  @default_read_limit 8_000

  @type workplace :: Path.t()
  @type result(t) :: {:ok, t} | {:error, String.t()}

  @doc """
  Read a file's full raw contents (no banner, no slicing).
  Used by tools that need exact content (e.g. edit_file).
  """
  @spec read_file_raw(Path.t(), workplace) :: result(binary())
  def read_file_raw(path, workplace) do
    with {:ok, expanded} <- ScopeGuard.validate(path, workplace) do
      case File.read(expanded) do
        {:ok, content} -> {:ok, content}
        {:error, reason} -> {:error, "Failed to read #{expanded}: #{reason}"}
      end
    end
  end

  @doc """
  Read file contents with a banner and optional byte slicing.

  - `offset`: byte offset to start from (default 0)
  - `limit`:  max bytes to return (default #{@default_read_limit}). 0 = whole file.

  Returns `{:ok, banner <> slice}` so the caller knows what they got.
  """
  @spec read_file(Path.t(), workplace, non_neg_integer(), non_neg_integer()) :: result(binary())
  def read_file(path, workplace, offset \\ 0, limit \\ @default_read_limit) do
    with {:ok, expanded} <- ScopeGuard.validate(path, workplace) do
      case File.read(expanded) do
        {:ok, content} -> {:ok, slice_with_banner(expanded, content, offset, limit)}
        {:error, reason} -> {:error, "Failed to read #{expanded}: #{reason}"}
      end
    end
  end

  @doc """
  Write `content` to `path`. Refuses to clobber unless `overwrite: true`.
  Creates parent directories as needed.
  """
  @spec write_file(Path.t(), workplace, binary(), boolean()) :: result(String.t())
  def write_file(path, workplace, content, overwrite \\ false) do
    with {:ok, expanded} <- ScopeGuard.validate(path, workplace) do
      if File.exists?(expanded) and overwrite != true do
        {:error,
         "File exists: #{expanded}. Pass overwrite: true to clobber. " <>
           "(Show me what's there first.)"}
      else
        expanded |> Path.dirname() |> File.mkdir_p!()
        File.write!(expanded, content)
        {:ok, "Wrote #{byte_size(content)} bytes to #{expanded}"}
      end
    end
  end

  @spec list_dir(Path.t(), workplace) :: result([String.t()])
  def list_dir(path, workplace) do
    with {:ok, expanded} <- ScopeGuard.validate(path, workplace) do
      case File.ls(expanded) do
        {:ok, files} -> {:ok, Enum.sort(files)}
        {:error, reason} -> {:error, "Failed to list #{expanded}: #{reason}"}
      end
    end
  end

  @spec file_size(Path.t(), workplace) :: result(non_neg_integer())
  def file_size(path, workplace) do
    with {:ok, expanded} <- ScopeGuard.validate(path, workplace) do
      case File.stat(expanded) do
        {:ok, %{size: size}} -> {:ok, size}
        {:error, reason} -> {:error, "Failed to stat #{expanded}: #{reason}"}
      end
    end
  end

  @doc """
  Create a timestamped `.backup.YYYY-MM-DD_HH-MM` sibling file.
  Refuses if the source doesn't exist.
  """
  @spec backup(Path.t(), workplace) :: result(String.t())
  def backup(path, workplace) do
    with {:ok, expanded} <- ScopeGuard.validate(path, workplace) do
      if File.exists?(expanded) do
        timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d_%H-%M")
        backup_path = "#{expanded}.backup.#{timestamp}"
        File.copy!(expanded, backup_path)
        {:ok, "Backed up to #{backup_path}"}
      else
        {:error, "Cannot backup: #{expanded} does not exist"}
      end
    end
  end

  # -- private --

  @spec slice_with_banner(Path.t(), binary(), non_neg_integer(), non_neg_integer()) :: binary()
  defp slice_with_banner(expanded, content, offset, limit) do
    total = byte_size(content)
    eff_offset = max(offset || 0, 0)
    raw_limit = if is_nil(limit), do: @default_read_limit, else: limit
    eff_limit = if raw_limit == 0, do: total, else: raw_limit

    if eff_offset >= total do
      "[read_file banner] path=#{expanded} total=#{total} offset=#{eff_offset} returned=0 (offset past EOF)\n"
    else
      take = min(eff_limit, total - eff_offset)
      slice = binary_part(content, eff_offset, take)

      next_hint =
        if eff_offset + take < total,
          do: " next_offset=#{eff_offset + take}",
          else: " (end of file)"

      banner =
        "[read_file banner] path=#{expanded} total=#{total} offset=#{eff_offset} returned=#{take}#{next_hint}\n"

      banner <> slice
    end
  end
end
