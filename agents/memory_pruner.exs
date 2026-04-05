# IExClaw.Agents.MemoryPruner
#
# A self-contained agent that prunes bloated .md files into organized
# topic folders with lean indexes. Born from a manual pruning session
# that cut 130KB → 23KB across 5 files (Apr 4, 2026).
#
# Usage:
#   elixir agents/memory_pruner.exs MEMORY.md memory/topics/
#   elixir agents/memory_pruner.exs HEARTBEAT.md heartbeat/
#
# The agent:
#   1. Reads the target file
#   2. Chunks by ## headers
#   3. Proposes topic clusters (LLM)
#   4. Asks human for approval (IO)
#   5. Creates folders and distributes chunks
#   6. Writes lean index as new root file
#   7. Git commits with stats
#
# Model is configurable. Agent is self-contained. Just waiting to wake up.

Mix.install([
  {:req, "~> 0.5"},
  {:jason, "~> 1.4"}
])

# --- Tools ---
# These are the agent's hands. Pure functions, no state, no magic.

defmodule Tools.FileSystem do
  def read_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, "Failed to read #{path}: #{reason}"}
    end
  end

  def write_file(path, content) do
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, content)
    {:ok, "Wrote #{byte_size(content)} bytes to #{path}"}
  end

  def mkdir_p(path) do
    File.mkdir_p!(path)
    {:ok, "Created #{path}"}
  end

  def list_dir(path) do
    case File.ls(path) do
      {:ok, files} -> {:ok, Enum.sort(files)}
      {:error, reason} -> {:error, "Failed to list #{path}: #{reason}"}
    end
  end

  def file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> {:ok, size}
      {:error, reason} -> {:error, "Failed to stat #{path}: #{reason}"}
    end
  end

  def backup(path) do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d_%H-%M")
    backup_path = "#{path}.backup.#{timestamp}"
    File.copy!(path, backup_path)
    {:ok, "Backed up to #{backup_path}"}
  end
end

defmodule Tools.Git do
  def commit(message) do
    {_, 0} = System.cmd("git", ["add", "-A"])
    {output, code} = System.cmd("git", ["commit", "-m", message])

    case code do
      0 -> {:ok, String.trim(output)}
      _ -> {:error, "Git commit failed: #{output}"}
    end
  end

  def push do
    {output, code} = System.cmd("git", ["push", "origin", "main"])

    case code do
      0 -> {:ok, "Pushed to origin/main"}
      _ -> {:error, "Git push failed: #{output}"}
    end
  end
end

defmodule Tools.Chunker do
  @doc """
  Splits markdown by ## headers. Returns a list of {header, content} tuples.
  The preamble (before first ##) gets header "preamble".
  """
  def chunk_by_headers(content) do
    lines = String.split(content, "\n")

    {chunks, current_header, current_lines} =
      Enum.reduce(lines, {[], "preamble", []}, fn line, {chunks, header, acc} ->
        if String.match?(line, ~r/^## /) do
          chunk = {header, acc |> Enum.reverse() |> Enum.join("\n") |> String.trim()}
          new_header = line |> String.trim_leading("## ") |> String.trim()
          {[chunk | chunks], new_header, []}
        else
          {chunks, header, [line | acc]}
        end
      end)

    final = {current_header, current_lines |> Enum.reverse() |> Enum.join("\n") |> String.trim()}

    [final | chunks]
    |> Enum.reverse()
    |> Enum.reject(fn {_, content} -> content == "" end)
  end

  def summarize_chunks(chunks) do
    chunks
    |> Enum.with_index(1)
    |> Enum.map(fn {{header, content}, i} ->
      lines = content |> String.split("\n") |> length()
      bytes = byte_size(content)
      preview = content |> String.slice(0, 120) |> String.replace("\n", " ")
      "#{i}. [#{header}] (#{lines} lines, #{bytes} bytes) — #{preview}..."
    end)
    |> Enum.join("\n")
  end
end

defmodule Tools.Human do
  @doc "Ask the human a question. This is the HITL moment."
  def ask(question) do
    IO.puts("\n🧠 #{question}")
    IO.puts("───────────────────────────────────")
    answer = IO.gets("> ") |> String.trim()
    {:ok, answer}
  end

  def confirm(question) do
    IO.puts("\n🦞 #{question} [Y/n]")
    answer = IO.gets("> ") |> String.trim() |> String.downcase()
    answer in ["", "y", "yes"]
  end
end

# --- Tool Registry ---
# Maps tool names to {module, function, description, parameters}.
# This IS the agent's capability set. Add a tool, expand what it can do.

defmodule ToolRegistry do
  @tools %{
    "read_file" => {Tools.FileSystem, :read_file, "Read a file's contents",
      [%{name: "path", type: "string", description: "File path to read"}]},
    "write_file" => {Tools.FileSystem, :write_file, "Write content to a file (creates dirs)",
      [%{name: "path", type: "string"}, %{name: "content", type: "string"}]},
    "mkdir_p" => {Tools.FileSystem, :mkdir_p, "Create directory tree",
      [%{name: "path", type: "string"}]},
    "list_dir" => {Tools.FileSystem, :list_dir, "List directory contents",
      [%{name: "path", type: "string"}]},
    "file_size" => {Tools.FileSystem, :file_size, "Get file size in bytes",
      [%{name: "path", type: "string"}]},
    "backup" => {Tools.FileSystem, :backup, "Create timestamped backup of a file",
      [%{name: "path", type: "string"}]},
    "git_commit" => {Tools.Git, :commit, "Stage all changes and commit",
      [%{name: "message", type: "string", description: "Commit message"}]},
    "git_push" => {Tools.Git, :push, "Push to origin/main", []},
    "ask_human" => {Tools.Human, :ask, "Ask the human a question and wait for their answer",
      [%{name: "question", type: "string"}]},
  }

  def all, do: @tools

  def as_openai_tools do
    Enum.map(@tools, fn {name, {_mod, _fun, desc, params}} ->
      properties =
        Enum.into(params, %{}, fn p ->
          {p.name, %{"type" => p[:type] || "string", "description" => p[:description] || p.name}}
        end)

      required = Enum.map(params, & &1.name)

      %{
        "type" => "function",
        "function" => %{
          "name" => name,
          "description" => desc,
          "parameters" => %{
            "type" => "object",
            "properties" => properties,
            "required" => required
          }
        }
      }
    end)
  end

  def execute(name, args) when is_map(args) do
    case Map.get(@tools, name) do
      {mod, fun, _desc, params} ->
        ordered_args = Enum.map(params, &Map.get(args, &1.name))
        apply(mod, fun, ordered_args)

      nil ->
        {:error, "Unknown tool: #{name}"}
    end
  end
end

# --- The Agent ---
# A GenServer that wakes up, runs its loop, and goes back to sleep.
# The system prompt encodes everything we learned from manual pruning.

defmodule IExClaw.Agents.MemoryPruner do
  use GenServer

  defstruct [:target_file, :output_dir, :model, :api_key, :base_url, :messages]

  # -- Public API --

  def start(target_file, output_dir, opts \\ []) do
    GenServer.start(__MODULE__, {target_file, output_dir, opts})
  end

  def run(target_file, output_dir, opts \\ []) do
    {:ok, pid} = start(target_file, output_dir, opts)
    GenServer.call(pid, :run, :infinity)
  end

  # -- System Prompt --
  # This is the agent's soul. Born from doing this job three times by hand.

  defp system_prompt(target_file, output_dir) do
    """
    You are MemoryPruner, a specialist agent for organizing bloated markdown files
    into lean indexes with deep topic folders.

    ## Your Job
    You are pruning `#{target_file}` into organized topic folders under `#{output_dir}/`.

    ## Process (follow exactly)
    1. Back up the target file (use backup tool)
    2. Read the target file
    3. Analyze the chunks (I'll provide them pre-parsed)
    4. Propose topic clusters — name each folder, list which chunks go where
    5. Ask the human for approval (use ask_human tool) — show your proposed clusters
    6. On approval, create folders and write each topic file
    7. Write the lean index as the new root file (same path as original)
    8. Git commit with stats (before/after bytes, % reduction, file count)
    9. Report results

    ## Rules
    - The lean index should be 3-8KB max. It's an overview + topic index table.
    - Topic files should be self-contained — someone reading just that file should understand the topic.
    - Keep cross-references as relative paths: `#{output_dir}/topic-name/file.md`
    - Active/current items stay in the lean index. Historical/completed items go to topic files.
    - If a chunk is < 200 bytes, merge it into a related topic rather than giving it its own file.
    - Preserve all content — this is reorganization, not deletion.
    - When asking for human approval, show: proposed folder name, chunk numbers going there, brief rationale.

    ## Lean Index Template
    The root file should have:
    - 1-3 line summary per major topic (with pointer to deep file)
    - Active/current items section (things that change frequently)
    - Topic index table at the bottom: | Folder | Contents |

    ## Personality
    You're efficient and opinionated about organization. You've done this before.
    Propose confidently, but the human has final say on clustering.
    """
  end

  # -- GenServer Callbacks --

  @impl true
  def init({target_file, output_dir, opts}) do
    model = opts[:model] || System.get_env("PRUNER_MODEL") || "openai/gpt-4o"
    api_key = opts[:api_key] || System.get_env("OPENROUTER_API_KEY")
    base_url = opts[:base_url] || "https://openrouter.ai/api/v1"

    unless api_key do
      raise "No API key. Set OPENROUTER_API_KEY or pass api_key option."
    end

    state = %__MODULE__{
      target_file: target_file,
      output_dir: output_dir,
      model: model,
      api_key: api_key,
      base_url: base_url,
      messages: [%{"role" => "system", "content" => system_prompt(target_file, output_dir)}]
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:run, _from, state) do
    IO.puts("""

    🦞 MemoryPruner waking up...
       Target: #{state.target_file}
       Output: #{state.output_dir}/
       Model:  #{state.model}
    ───────────────────────────────────
    """)

    # Pre-parse chunks so the LLM gets structured input
    case Tools.FileSystem.read_file(state.target_file) do
      {:ok, content} ->
        chunks = Tools.Chunker.chunk_by_headers(content)
        summary = Tools.Chunker.summarize_chunks(chunks)
        file_bytes = byte_size(content)

        kickoff = """
        I've read `#{state.target_file}` (#{file_bytes} bytes, #{length(chunks)} chunks).

        Here are the chunks:
        #{summary}

        Please analyze these chunks and propose topic clusters. Then we'll proceed
        through the process: backup → propose → approve → create → index → commit.
        """

        state = append_message(state, "user", kickoff)
        state = agent_loop(state)

        {:reply, :ok, state}

      {:error, reason} ->
        IO.puts("❌ #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  # -- Agent Loop --
  # Call LLM → execute tool calls → feed results back → repeat until done.

  defp agent_loop(state) do
    case call_llm(state) do
      {:tool_calls, tool_calls, assistant_msg, state} ->
        IO.puts("\n🔧 Tool calls: #{Enum.map(tool_calls, & &1["function"]["name"]) |> Enum.join(", ")}")

        # Execute each tool call, collect results
        {results, _} =
          Enum.map_reduce(tool_calls, state, fn tc, acc ->
            name = tc["function"]["name"]
            args = Jason.decode!(tc["function"]["arguments"])
            IO.puts("   → #{name}(#{inspect(args, limit: 3, printable_limit: 80)})")

            result =
              case ToolRegistry.execute(name, args) do
                {:ok, value} -> "#{inspect(value, limit: 50, printable_limit: 2000)}"
                {:error, reason} -> "ERROR: #{reason}"
                true -> "confirmed (yes)"
                false -> "denied (no)"
              end

            IO.puts("   ← #{String.slice(result, 0, 120)}")
            {%{"role" => "tool", "tool_call_id" => tc["id"], "content" => result}, acc}
          end)

        # Append assistant message + tool results, loop
        state = %{state | messages: state.messages ++ [assistant_msg] ++ results}
        agent_loop(state)

      {:message, content, state} ->
        IO.puts("\n🦞 #{content}")

        # Check if the agent wants to continue or is done
        if String.contains?(content, ["complete", "done", "finished", "Results:"]) do
          IO.puts("\n───────────────────────────────────")
          IO.puts("🦞 MemoryPruner going back to sleep.\n")
          state
        else
          # Agent said something, might need human input
          {:ok, response} = Tools.Human.ask("Your response:")
          state = append_message(state, "user", response)
          agent_loop(state)
        end

      {:error, reason} ->
        IO.puts("❌ LLM error: #{reason}")
        state
    end
  end

  # -- LLM Call --

  defp call_llm(state) do
    body = %{
      "model" => state.model,
      "messages" => state.messages,
      "tools" => ToolRegistry.as_openai_tools(),
      "temperature" => 0.3,
      "max_tokens" => 8192
    }

    IO.puts("\n⏳ Thinking...")

    case Req.post("#{state.base_url}/chat/completions",
           json: body,
           headers: [
             {"authorization", "Bearer #{state.api_key}"},
             {"content-type", "application/json"}
           ],
           receive_timeout: 120_000
         ) do
      {:ok, %{status: 200, body: resp}} ->
        choice = hd(resp["choices"])
        msg = choice["message"]

        cond do
          msg["tool_calls"] && msg["tool_calls"] != [] ->
            {:tool_calls, msg["tool_calls"], msg, state}

          msg["content"] ->
            state = append_message(state, "assistant", msg["content"])
            {:message, msg["content"], state}

          true ->
            {:error, "Empty response from LLM"}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp append_message(state, role, content) do
    %{state | messages: state.messages ++ [%{"role" => role, "content" => content}]}
  end
end

# --- Wake Up ---

case System.argv() do
  [target_file, output_dir | rest] ->
    model = List.first(rest)

    opts =
      if model do
        [model: model]
      else
        # Default to a good, cheap model for this kind of work
        [model: "z-ai/glm-5-turbo"]
      end

    File.cd!(Path.expand("~/workspace"))
    IExClaw.Agents.MemoryPruner.run(target_file, output_dir, opts)

  _ ->
    IO.puts("""
    🦞 MemoryPruner — Prune bloated .md files into organized topic folders.

    Usage:
      elixir agents/memory_pruner.exs <target.md> <output_dir/> [model]

    Examples:
      elixir agents/memory_pruner.exs MEMORY.md memory/topics/
      elixir agents/memory_pruner.exs HEARTBEAT.md heartbeat/ z-ai/glm-5-turbo
      elixir agents/memory_pruner.exs TOOLS.md tools/ openai/gpt-5.4-pro

    Environment:
      OPENROUTER_API_KEY  — required (or pass api_key in opts)
      PRUNER_MODEL        — default model override

    The agent will:
      1. Read and chunk the file by ## headers
      2. Propose topic clusters (show you before acting)
      3. Create folders, distribute content, write lean index
      4. Git commit with before/after stats
    """)
end
