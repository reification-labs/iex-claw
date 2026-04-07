defmodule IExClaw.Tools.AgentLogger do
  @moduledoc """
  Append-only growth log for an agent. Every call writes one line to a
  timestamped-per-minute file AND to a rolling `growth.md` in the same
  directory. "Growth leaves a trace."

  Unlike the original inline version in `code.exs`, this module is parametric:
  the log directory is passed at call time, so any agent can reuse it by
  pointing at its own `logs/` folder.

  Extracted from `agents/code/code.exs` on 2026-04-05 during the
  "earn the substrate" molt — step 1 of the Messages/AgentLogger pull.
  """

  alias IExClaw.Tools.ScopeGuard

  @type log_dir :: Path.t()
  @type result :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Append `message` to the agent's growth log at `log_dir`.

  - Writes one line to `<log_dir>/<YYYY-MM-DD_HH-MM-SS>.md`
  - Also appends the same line to the rolling `<log_dir>/growth.md`
  - The `agent_name` is included in the line prefix for human scanning.
  - `log_dir` is validated against `workplace` via `ScopeGuard` so callers
    cannot write outside their scope.

  Returns `{:ok, path_written}` or `{:error, reason}`.
  """
  @spec log(String.t(), String.t(), log_dir(), Path.t()) :: result()
  def log(agent_name, message, log_dir, workplace)
      when is_binary(agent_name) and is_binary(message) and is_binary(log_dir) and is_binary(workplace) do
    with {:ok, expanded_dir} <- ScopeGuard.validate(log_dir, workplace),
         :ok <- File.mkdir_p(expanded_dir) do
      timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d_%H-%M-%S")
      entry = "[#{timestamp}] #{agent_name}: #{message}\n"

      per_tick_path = Path.join(expanded_dir, "#{timestamp}.md")
      rolling_path = Path.join(expanded_dir, "growth.md")

      File.write!(per_tick_path, entry, [:append])
      File.write!(rolling_path, entry, [:append])

      {:ok, "Logged to #{per_tick_path}"}
    end
  end
end
