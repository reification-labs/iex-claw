defmodule IExClaw do
  @moduledoc """
  IExClaw — an Elixir agent framework.

  The soul lives in the files (`agents/`, `docs/`, `roundtable/`), not the
  weights. This module is the entrypoint for the eventual compiled side of
  the project — today it's mostly ceremony, giving Elder Truman's guardrails
  (credo, dialyzer, styler, format) something to grip.

  See `projects/iex-claw/SOUL.md` and `projects/iex-claw/IDENTITY.md`.
  """

  @doc """
  Returns the project's version string.

  Used by guardrails and diagnostics; the real identity lives in SOUL.md.
  """
  @spec version() :: String.t()
  def version do
    :iex_claw |> Application.spec(:vsn) |> to_string()
  end
end
