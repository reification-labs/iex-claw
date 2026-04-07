# IExClaw.TickCode
#
# Wrap Code's real LLM loop in the tick protocol.
# One message per tick. Real tokens. Real filesystem I/O.
#
# Usage:
#   elixir agents/tick_code.exs --dry-run    # simulate: read inbox, no LLM
#   elixir agents/tick_code.exs              # LIVE: drain inbox, real tokens
#   elixir agents/tick_code.exs --max 2      # cap cycles (default 3)
#
# process_fn hook: one inbox message → IExClaw.Agents.Code.run/1 → summary.

# Load libraries (skip their top-level CLI/demo blocks)
System.put_env("IEXCLAW_SKIP_DEMO", "1")
System.put_env("IEXCLAW_CODE_LIB", "1")
Code.require_file("tick.exs", __DIR__)
Code.require_file("inbox_tick.exs", __DIR__)
Code.require_file("code/code.exs", __DIR__)

defmodule IExClaw.TickCode do
  @home Path.expand("../../iex-claw", __DIR__)
  @inbox Path.join(@home, "messages/inbox/code")
  @processed Path.join(@home, "messages/inbox/code/processed")

  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run, false)
    max_cycles = Keyword.get(opts, :max, 3)
    budget = Keyword.get(opts, :budget, 1)

    IO.puts("\n🦞 TickCode — draining Code's inbox, one tick at a time\n")
    IO.puts("  inbox:   #{@inbox}")
    IO.puts("  dry_run: #{dry_run?}")
    IO.puts("  budget:  #{budget}")
    IO.puts("  max:     #{max_cycles}")
    IO.puts(String.duplicate("─", 60))

    File.mkdir_p!(@processed)
    pending = list_pending()
    IO.puts("\n📬 #{length(pending)} messages pending in Code's inbox")

    if pending == [] do
      IO.puts("\n✨ Inbox empty. Nothing to tick.\n")
      :empty
    else
      Enum.each(pending, fn p -> IO.puts("  • #{Path.basename(p)}") end)

      process_fn = if dry_run?, do: &dry_process/3, else: &live_process/3

      tickable =
        IExClaw.InboxTickable.new(
          name: "code",
          inbox: @inbox,
          processed_dir: @processed,
          process_fn: process_fn,
          move?: not dry_run?
        )

      loop([{:code, IExClaw.InboxTickable, tickable}], budget, max_cycles, 1)
    end
  end

  defp list_pending do
    @inbox
    |> File.ls!()
    |> Enum.map(&Path.join(@inbox, &1))
    |> Enum.filter(&File.regular?/1)
    |> Enum.filter(&String.ends_with?(&1, [".msg.json", ".md"]))
    |> Enum.sort()
  end

  defp loop(_children, _budget, max, n) when n > max do
    IO.puts("\n⛔ Reached max cycles (#{max}). Stopping.")
    :max_reached
  end

  defp loop(children, budget, max, n) do
    result = IExClaw.Tick.Pump.cycle(children, budget)
    IO.puts("\n⏱  cycle #{n}  (budget=#{budget})")

    Enum.each(result.worked, fn {name, summary} ->
      IO.puts("  💪 #{name}:")

      summary
      |> String.split("\n")
      |> Enum.take(10)
      |> Enum.each(fn line -> IO.puts("     #{line}") end)
    end)

    if result.idled != [], do: IO.puts("  😴 idle: #{inspect(result.idled)}")

    next_children =
      Enum.map(children, fn {name, mod, _} ->
        {name, mod, Map.fetch!(result.states, name)}
      end)

    if result.worked == [] do
      IO.puts(String.duplicate("─", 60))
      IO.puts("\n✨ All agents idle. Inbox drained after #{n - 1} cycles.\n")
      :drained
    else
      loop(next_children, budget, max, n + 1)
    end
  end

  # -- process_fn implementations --

  defp dry_process(_name, path, body) do
    task = extract_task(body)

    """
    [DRY RUN] Would feed to Code.run/1:
      file: #{Path.basename(path)}
      task: #{String.slice(task, 0, 140)}
    """
  end

  defp live_process(_name, path, body) do
    task = extract_task(body)
    IO.puts("\n     → calling Code.run/1 with task from #{Path.basename(path)}...")

    case IExClaw.Agents.Code.run(task) do
      {:ok, summary} -> "handled #{Path.basename(path)}\n\n#{summary}"
      {:error, reason} -> "⚠️  Code failed on #{Path.basename(path)}: #{inspect(reason)}"
    end
  rescue
    e -> "💥 crashed on #{Path.basename(path)}: #{Exception.message(e)}"
  end

  defp extract_task(body) do
    case Jason.decode(body) do
      {:ok, %{"parts" => parts}} ->
        parts
        |> Enum.filter(fn p -> p["kind"] in ["text", "feedback", "directive"] end)
        |> Enum.map_join("\n\n", fn
          %{"kind" => "text", "text" => t} -> t
          %{"kind" => "feedback", "observation" => o, "request" => r} -> "#{o}\n#{r}"
          %{"text" => t} -> t
          p -> inspect(p)
        end)

      _ ->
        body
    end
  end
end

# Parse CLI and run
opts =
  System.argv()
  |> Enum.chunk_every(2, 1, [nil])
  |> Enum.reduce(%{dry_run: false, max: 3, budget: 1}, fn
    ["--dry-run" | _], acc -> %{acc | dry_run: true}
    ["--max", v], acc when is_binary(v) ->
      case Integer.parse(v) do
        {n, ""} -> %{acc | max: n}
        _ -> acc
      end
    _, acc -> acc
  end)
  |> Map.to_list()

IExClaw.TickCode.run(opts)
