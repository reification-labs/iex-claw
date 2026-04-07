defmodule IExClaw.Agents.Web do
  @moduledoc """
  WEB — The Project's Web Store (NPC).

  A per-project, DIRT-backed fetch/cache/tmp/history store.
  Agents ask Web; Web serves. Network access is centralized,
  auditable, and cacheable.

  Bus neighbor to Postmaster — handles outbound URL legs.
  """

  @type fetch_result :: {:ok, %{path: Path.t(), status: pos_integer(), cache_hit: boolean()}} | {:error, term()}

  @doc """
  Fetch a URL, write body to cache/, and return the result.

  Options: `:cache_ttl` (seconds), `:headers` (keyword list).
  """
  @spec fetch(String.t(), keyword()) :: fetch_result()
  def fetch(_url, _opts), do: {:error, :not_implemented}

  @doc """
  Return the cached body for a URL, or :miss if not cached.
  """
  @spec cache_get(String.t()) :: {:ok, binary()} | :miss
  def cache_get(_url), do: :miss

  @doc """
  Explicitly write a body to cache with optional metadata.
  """
  @spec cache_put(String.t(), binary(), map()) :: :ok | {:error, term()}
  def cache_put(_url, _body, _meta), do: :ok

  @doc """
  Append a fetch event entry to history.jsonl.
  """
  @spec history_append(map()) :: :ok
  def history_append(_entry), do: :ok

  @doc """
  Return a path inside tmp/ for staging or downloads.
  """
  @spec tmp_path(String.t()) :: Path.t()
  def tmp_path(name), do: Path.join([project_web_dir(), "tmp", name])

  @doc """
  Sweep tmp files older than N seconds. Returns count removed.
  """
  @spec clean_tmp(non_neg_integer()) :: {:ok, non_neg_integer()}
  def clean_tmp(_older_than), do: {:ok, 0}

  # Private helpers (stubs)

  defp project_web_dir do
    # Will resolve to projects/<proj>/web/ at runtime
    "projects/.web"
  end
end
