# IExClaw.ProjectTick
#
# Project owns the clock. Project pumps its children.
# "I want to give X a chance to decide what it needs to do."
#
# Children currently: Code, Goal.
# Each child is an InboxTickable wrapping its messages/inbox/<name>/ dir.
#
# Usage:
#   elixir agents/project_tick.exs --dry-run       # read inboxes, don't call LLMs
#   elixir agents/project_tick.exs                 # LIVE tokens per tick
#   elixir agents/project_tick.exs --budget 2      # 2 units of work per cycle
#   elixir agents/project_tick.exs --max 10        # cap cycles (default 6)
#
# The pump fairness policy is IExClaw.Tick.Pump's default: children are
# offered ticks in declared order; each returning :work consumes one
# budget-unit; when budget is spent, remaining children are :skipped and
# try next cycle.

System.put_env("IEXCLAW_SKIP_DEMO", "1")
System.put_env("IEXCLAW_CODE_LIB", "1")
System.put_env("IEXCLAW_GOAL_LIB", "1")
Code.require_file("tick.exs", __DIR__)
Code.require_file("inbox_tick.exs", __DIR__)
Code.require_file("code/code.exs", __DIR__)
Code.require_file("goal/goal.exs", __DIR__)

defmodule IExClaw.ProjectTick do
  @home Path.expand("../../iex-claw", __DIR__)
  @code_inbox Path.join(@home, "messages/inbox/code")
  @goal_inbox Path.join(@home, "messages/inbox/goal")

  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run, false)
    max_cycles = Keyword.get(opts, :max, 6)
    budget = Keyword.get(opts, :budget, 1)

    IO.puts("\n🦞 IExClaw Project — pumping blood to Code and Goal\n")
    IO.puts("  dry_run: #{dry_run?}")
    IO.puts("  budget:  #{budget} unit(s) of work per cycle")
    IO.puts("  max:     #{max_cycles} cycles")
    IO.puts(String.duplicate("─", 60))

    children = build_children(dry_run?)
    announce_children(children)

    loop(children, budget, max_cycles, 1, dry_run?)
  end

  defp build_children(dry_run?) do
    code_fn = if dry_run?, do: dry_fn("code"), else: live_fn(:code)
    goal_fn = if dry_run?, do: dry_fn("goal"), else: live_fn(:goal)

    code_state =
      IExClaw.InboxTickable.new(
        name: "code",
        inbox: @code_inbox,
        process_fn: code_fn,
        move?: not dry_run?
      )

    goal_state =
      IExClaw.InboxTickable.new(
        name: "goal",
        inbox: @goal_inbox,
        process_fn: goal_fn,
        move?: not dry_run?
      )

    [
      {:code, IExClaw.InboxTickable, code_state},
      {:goal, IExClaw.InboxTickable, goal_state}
    ]
  end

  defp announce_children(children) do
    IO.puts("\n📬 inbox census:")

    Enum.each(children, fn {name, _mod, state} ->
      pending =
        state.inbox
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, [".msg.json", ".md"]))
        |> length()

      IO.puts("  • #{name}: #{pending} pending in #{Path.relative_to_cwd(state.inbox)}")
    end)
  end

  defp loop(_children, _budget, max, n, _dry) when n > max do
    IO.puts("\n⛔ Reached max cycles (#{max}).")
    :max_reached
  end

  defp loop(children, budget, max, n, dry_run?) do
    result = IExClaw.Tick.Pump.cycle(children, budget)
    IO.puts("\n⏱  cycle #{n}  (budget=#{budget})")

    Enum.each(result.worked, fn {name, summary} ->
      IO.puts("  💪 #{name}:")

      summary
      |> String.split("\n")
      |> Enum.take(6)
      |> Enum.each(fn line -> IO.puts("     #{line}") end)
    end)

    if result.idled != [], do: IO.puts("  😴 idle: #{inspect(result.idled)}")
    if result.skipped != [], do: IO.puts("  ⏭  skipped: #{inspect(result.skipped)}")

    next_children =
      Enum.map(children, fn {name, mod, _} ->
        {name, mod, Map.fetch!(result.states, name)}
      end)

    if result.worked == [] do
      IO.puts(String.duplicate("─", 60))
      IO.puts("\n✨ All children idle. Inboxes drained after #{n - 1} cycles.")
      IO.puts("   (#{if dry_run?, do: "DRY RUN — messages untouched", else: "LIVE — messages moved to processed/"})\n")
      :drained
    else
      loop(next_children, budget, max, n + 1, dry_run?)
    end
  end

  # -- process_fn factories --

  defp dry_fn(name) do
    fn _n, path, body ->
      task = extract_task(body)

      """
      [DRY RUN #{name}] would handle #{Path.basename(path)}
      task: #{String.slice(task, 0, 120)}
      """
    end
  end

  defp live_fn(:code) do
    fn _n, path, body ->
      task = extract_task(body)
      IO.puts("\n     → Code.run/1 on #{Path.basename(path)}...")

      try do
        case IExClaw.Agents.Code.run(task) do
          {:ok, summary} -> "[code] #{Path.basename(path)}\n#{summary}"
          {:error, reason} -> "⚠️  code failed: #{inspect(reason)}"
        end
      rescue
        e -> "💥 code crashed: #{Exception.message(e)}"
      end
    end
  end

  defp live_fn(:goal) do
    fn _n, path, body ->
      task = extract_task(body)
      IO.puts("\n     → Goal.run/1 on #{Path.basename(path)}...")

      try do
        case IExClaw.Agents.Goal.run(task) do
          {:ok, summary} -> "[goal] #{Path.basename(path)}\n#{summary}"
          {:error, reason} -> "⚠️  goal failed: #{inspect(reason)}"
        end
      rescue
        e -> "💥 goal crashed: #{Exception.message(e)}"
      end
    end
  end

  defp extract_task(body) do
    case Jason.decode(body) do
      {:ok, %{"parts" => parts}} ->
        parts
        |> Enum.filter(fn p -> p["kind"] in ["text", "feedback", "directive", "proposal"] end)
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

# -- parse CLI --
opts =
  System.argv()
  |> Enum.chunk_every(2, 1, [nil])
  |> Enum.reduce(%{dry_run: false, max: 6, budget: 1}, fn
    ["--dry-run" | _], acc ->
      %{acc | dry_run: true}

    ["--max", v], acc when is_binary(v) ->
      case Integer.parse(v) do
        {n, ""} -> %{acc | max: n}
        _ -> acc
      end

    ["--budget", v], acc when is_binary(v) ->
      case Integer.parse(v) do
        {n, ""} -> %{acc | budget: n}
        _ -> acc
      end

    _, acc ->
      acc
  end)
  |> Map.to_list()

IExClaw.ProjectTick.run(opts)
