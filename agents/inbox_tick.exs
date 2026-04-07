# IExClaw.InboxTickable
#
# An InboxTickable is an agent-shaped thing that watches a directory,
# pops ONE message per tick, processes it, moves it to processed/,
# and goes idle when the inbox is empty.
#
# This is the shape most real agents will take: "check inbox → do one
# thing → yield." One unit of work per cycle. Multi-step plans emerge
# from the inbox refilling across cycles.
#
# The `process_fn` is the hook where LLMs plug in later. Today it's
# just `IO.inspect`. Tomorrow it's `Code.handle_message/2`.
#
# Usage (standalone demo):
#   elixir agents/inbox_tick.exs
#
# Requires tick.exs to be loaded (for IExClaw.Tickable behaviour).

System.put_env("IEXCLAW_SKIP_DEMO", "1")
Code.require_file("tick.exs", __DIR__)

# --- The Inbox-backed Tickable ---
# The file wins. DIRT all the way down.

defmodule IExClaw.InboxTickable do
  @moduledoc """
  Wraps an inbox directory into a Tickable.

  State shape:
    %{
      name: String.t(),
      inbox: Path.t(),               # absolute path to messages/inbox/<agent>/
      processed_dir: Path.t(),       # where handled messages go
      process_fn: (name, msg_path, body -> String.t()),
      handled: non_neg_integer()
    }

  One tick = zero-or-one message consumed.
  """

  @behaviour IExClaw.Tickable

  @type state :: %{
          name: String.t(),
          inbox: Path.t(),
          processed_dir: Path.t(),
          process_fn: (String.t(), Path.t(), String.t() -> String.t()),
          handled: non_neg_integer()
        }

  @spec new(keyword()) :: state()
  def new(opts) do
    name = Keyword.fetch!(opts, :name)
    inbox = Keyword.fetch!(opts, :inbox) |> Path.expand()
    processed_dir = Keyword.get(opts, :processed_dir, Path.join(inbox, "processed"))
    process_fn = Keyword.get(opts, :process_fn, &default_process/3)
    move? = Keyword.get(opts, :move?, true)

    File.mkdir_p!(inbox)
    File.mkdir_p!(processed_dir)

    %{
      name: name,
      inbox: inbox,
      processed_dir: processed_dir,
      process_fn: process_fn,
      move?: move?,
      handled: 0,
      seen: MapSet.new()
    }
  end

  @impl true
  @spec tick(state(), map()) :: IExClaw.Tickable.tick_result()
  def tick(state, _meta \\ %{}) do
    case next_message(state.inbox, state.seen) do
      nil ->
        {:idle, state}

      msg_path ->
        body = File.read!(msg_path)
        summary = state.process_fn.(state.name, msg_path, body)

        new_state =
          if state.move? do
            move_to_processed(msg_path, state.processed_dir)
            %{state | handled: state.handled + 1}
          else
            # Dry run: don't move, but remember we've seen it so we don't loop.
            %{state | handled: state.handled + 1, seen: MapSet.put(state.seen, msg_path)}
          end

        {:work, summary, new_state}
    end
  end

  # -- helpers --

  @spec next_message(Path.t(), MapSet.t()) :: Path.t() | nil
  defp next_message(inbox, seen) do
    inbox
    |> File.ls!()
    |> Enum.map(&Path.join(inbox, &1))
    |> Enum.filter(&File.regular?/1)
    |> Enum.filter(&String.ends_with?(&1, [".md", ".msg.json", ".txt"]))
    |> Enum.reject(&MapSet.member?(seen, &1))
    |> Enum.sort()
    |> List.first()
  end

  @spec move_to_processed(Path.t(), Path.t()) :: :ok
  defp move_to_processed(src, processed_dir) do
    dest = Path.join(processed_dir, Path.basename(src))
    File.rename!(src, dest)
    :ok
  end

  @spec default_process(String.t(), Path.t(), String.t()) :: String.t()
  defp default_process(name, path, body) do
    first_line = body |> String.split("\n", parts: 2) |> List.first() |> String.slice(0, 60)
    "#{name}: handled #{Path.basename(path)} — #{first_line}"
  end
end

# --- Demo ---
# Seed fake inboxes, tick them until idle, watch the blood flow.

defmodule InboxDemo do
  @demo_root Path.expand("../.tick-demo", __DIR__)

  def go do
    IO.puts("\n🦞 InboxTickable Demo — inboxes as agent wills\n")
    IO.puts(String.duplicate("─", 60))

    reset_demo()
    seed_messages()

    code =
      IExClaw.InboxTickable.new(
        name: "code",
        inbox: Path.join(@demo_root, "code/inbox"),
        process_fn: fn name, path, body ->
          # This is where the LLM call will eventually live.
          # For now: extract the first line as "what we would work on".
          task = body |> String.split("\n") |> List.first() |> String.trim_leading("# ")
          "#{name}: 🧬 grew something for '#{task}' (#{Path.basename(path)})"
        end
      )

    goal =
      IExClaw.InboxTickable.new(
        name: "goal",
        inbox: Path.join(@demo_root, "goal/inbox"),
        process_fn: fn name, path, body ->
          verdict = if String.contains?(body, "bless"), do: "blessed ✅", else: "rewrote ✏️"
          "#{name}: #{verdict} — #{Path.basename(path)}"
        end
      )

    children = [
      {:code, IExClaw.InboxTickable, code},
      {:goal, IExClaw.InboxTickable, goal}
    ]

    # Pump until everyone is idle (or we hit max_cycles safety valve)
    run_until_idle(children, [budget: 1], 20)

    IO.puts(String.duplicate("─", 60))
    IO.puts("\n✨ Inboxes drained. #{count_processed()} messages handled.\n")
  end

  defp reset_demo do
    if File.exists?(@demo_root), do: File.rm_rf!(@demo_root)
    File.mkdir_p!(Path.join(@demo_root, "code/inbox"))
    File.mkdir_p!(Path.join(@demo_root, "goal/inbox"))
  end

  defp seed_messages do
    seed("code/inbox/001-add-inbox-tick.md", """
    # add inbox tick protocol
    Please grow a codelet that reads the inbox one message at a time.
    """)

    seed("code/inbox/002-heal-boundary-check.md", """
    # heal the boundary check in code.exs
    Code tried to write outside workplace once. Fix the guard.
    """)

    seed("code/inbox/003-document-heartbeat.md", """
    # document the heartbeat
    Add a docstring to heartbeat.exs explaining :self_request.
    """)

    seed("goal/inbox/001-review-inbox-tick.md", """
    # Goal: please review this
    I think we should bless the inbox tick protocol.
    """)

    seed("goal/inbox/002-review-big-change.md", """
    # Goal: review this risky change
    Does this change survive a vendor swap?
    """)
  end

  defp seed(rel, body) do
    path = Path.join(@demo_root, rel)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, body)
  end

  defp count_processed do
    Path.wildcard(Path.join(@demo_root, "**/processed/*.md")) |> length()
  end

  defp run_until_idle(_children, _opts, 0), do: :halted

  defp run_until_idle(children, opts, max) do
    budget = Keyword.get(opts, :budget, 1)
    result = IExClaw.Tick.Pump.cycle(children, budget)
    n = Keyword.get(opts, :n, 1)

    IO.puts("\n⏱  cycle #{n}  (budget=#{budget})")

    Enum.each(result.worked, fn {name, summary} -> IO.puts("  💪 #{name}: #{summary}") end)
    if result.idled != [], do: IO.puts("  😴 idle: #{inspect(result.idled)}")
    if result.skipped != [], do: IO.puts("  ⏭  skipped: #{inspect(result.skipped)}")

    next_children =
      Enum.map(children, fn {name, mod, _old} ->
        {name, mod, Map.fetch!(result.states, name)}
      end)

    if result.worked == [] and result.skipped == [] do
      :all_idle
    else
      run_until_idle(next_children, Keyword.put(opts, :n, n + 1), max - 1)
    end
  end
end

if System.get_env("IEXCLAW_SKIP_DEMO") != "1" do
  InboxDemo.go()
end
