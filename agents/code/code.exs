# IExClaw.Agents.Code
#
# Code. Not a coder. Not a code writer. Code.
# I am what the code wants.
#
# Usage:
#   elixir agents/code/code.exs "grow a new module for X"
#   elixir agents/code/code.exs "heal the bug in Y"
#   elixir agents/code/code.exs "repair stale patterns in Z"
#
# Or programmatically:
#   {:ok, pid} = IExClaw.Agents.Code.start_link()
#   IExClaw.Agents.Code.request(pid, "grow X")
#
# The agent:
#   1. Reads its soul documents on startup
#   2. Receives a task from Project or peer agents
#   3. Plans, reads, writes, edits — always within projects/iex-claw/
#   4. Returns a summary of what was done
#
# Model is configurable. Agent is self-contained. Just waiting to run.

Mix.install([
  {:req, "~> 0.5"},
  {:jason, "~> 1.4"}
])

# --- Load compiled delegated tools ---
# These live in lib/ and are compiled under mix test, but when code.exs runs
# standalone they need to be explicitly required onto the code path.

Code.require_file(Path.expand("../../lib/iex_claw/tools/scope_guard.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/file_system.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/edit_file.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/messages.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/agent_logger.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/run_logger.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tool_registry.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/llm_client.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/agent.ex", __DIR__))

# --- Constants ---
# The boundary. Love.

defmodule IExClaw.Agents.Code.Constants do
  @moduledoc false
  @home Path.expand("..", __DIR__)
  @workplace Path.expand("../..", __DIR__)

  def home, do: @home
  def workplace, do: @workplace
end

# --- Agent Logger ---
# Growth leaves a trace.

defmodule Tools.AgentLogger do
  @moduledoc """
  Thin delegator to the compiled `IExClaw.Tools.AgentLogger`.

  Keeps the `/2` public contract (`log(agent_name, message)`) stable
  while the real implementation lives in `lib/`.
  """

  alias IExClaw.Agents.Code.Constants

  @workplace Constants.workplace()
  @log_dir Path.join(Constants.home(), "logs")

  @spec log(String.t(), String.t()) :: {:ok, String.t()}
  def log(agent_name, message) do
    IExClaw.Tools.AgentLogger.log(agent_name, message, @log_dir, @workplace)
  end
end

# --- Messages ---
# The DIRT bus. Files are the wire. Goal speaks through these.

defmodule Tools.Messages do
  @moduledoc """
  Thin delegator to IExClaw.Tools.Messages.
  All real work (envelope building, inbox I/O, summarization) lives in lib/.
  This module preserves the external arities (/0, /1, /3, /4) for ToolRegistry.
  """

  alias IExClaw.Tools.Messages

  @agent "code"
  @workplace IExClaw.Agents.Code.Constants.workplace()
  @inbox_base Path.join(@workplace, "messages/inbox")

  @doc """
  Lists messages in Code's inbox, newest first.
  Delegates to `IExClaw.Tools.Messages.read_inbox/2`.
  """
  @spec read_inbox() :: {:ok, [map()]}
  def read_inbox do
    Messages.read_inbox(@agent, @inbox_base)
  end

  @doc """
  Reads a single message by id from Code's inbox.
  Delegates to `IExClaw.Tools.Messages.read_message/3`.
  """
  @spec read_message(String.t()) :: {:ok, map()} | {:error, String.t()}
  def read_message(id) do
    Messages.read_message(@agent, id, @inbox_base)
  end

  @doc """
  Sends a message to another agent's inbox.
  Delegates to `IExClaw.Tools.Messages.send_message/7`.
  """
  @spec send_message(String.t(), String.t(), [map()], keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def send_message(to, task_id, parts, opts \\ []) do
    Messages.send_message(@agent, to, task_id, parts, @inbox_base, @workplace, opts)
  end
end

# --- Scope Guard ---
# Boundaries are love.
# Delegates to the compiled module; keeps /1 arity for backward compat.

defmodule Tools.ScopeGuard do
  @moduledoc false
  alias IExClaw.Tools.ScopeGuard

  @workplace IExClaw.Agents.Code.Constants.workplace()

  def validate(path), do: ScopeGuard.validate(path, @workplace)
  def validate!(path), do: ScopeGuard.validate!(path, @workplace)
end

# --- Tools ---
# These are Code's hands. Pure functions, no state, no magic.

defmodule Tools.FileSystem do
  @moduledoc false
  alias IExClaw.Tools.FileSystem

  @workplace IExClaw.Agents.Code.Constants.workplace()

  def read_file_raw(path), do: FileSystem.read_file_raw(path, @workplace)
  def read_file(path, offset \\ 0, limit \\ 8000), do: FileSystem.read_file(path, @workplace, offset, limit)
  def write_file(path, content, overwrite \\ false), do: FileSystem.write_file(path, @workplace, content, overwrite)
  def list_dir(path), do: FileSystem.list_dir(path, @workplace)
  def file_size(path), do: FileSystem.file_size(path, @workplace)
  def backup(path), do: FileSystem.backup(path, @workplace)
end

defmodule Tools.EditFile do
  @moduledoc false
  @workplace IExClaw.Agents.Code.Constants.workplace()

  @doc """
  Targeted edits using [{old_text, new_text}] list.
  Delegates to IExClaw.Tools.EditFile.
  """
  def edit(path, edits) when is_list(edits), do: IExClaw.Tools.EditFile.edit(path, @workplace, edits)
end

# --- Tool Registry ---
# Maps tool names to {module, function, description, parameters}.
# This IS the agent's capability set.

defmodule ToolRegistry do
  @moduledoc false
  @tools %{
    "read_file" =>
      {Tools.FileSystem, :read_file,
       "Read a file's contents (optionally sliced). Returns a banner line with total/offset/returned bytes plus next_offset hint, followed by the slice. Use offset/limit to page through large files.",
       [
         %{name: "path", type: "string", description: "File path to read"},
         %{name: "offset", type: "integer", description: "Byte offset to start from (default 0)"},
         %{name: "limit", type: "integer", description: "Max bytes to return (default 8000, pass 0 for whole file)"}
       ]},
    "write_file" =>
      {Tools.FileSystem, :write_file,
       "Write content to a NEW file. Errors if file exists unless overwrite:true. Creates parent dirs.",
       [
         %{name: "path", type: "string", description: "Path for new file"},
         %{name: "content", type: "string", description: "Content to write"},
         %{name: "overwrite", type: "boolean", description: "Set to true to overwrite existing file"}
       ]},
    "edit_file" =>
      {Tools.EditFile, :edit,
       "Targeted edits to existing file. Each old_text must appear exactly once. Atomic — reads, validates, writes.",
       [
         %{name: "path", type: "string", description: "File to edit"},
         %{
           name: "edits",
           type: "array",
           description: "List of {old_text, new_text} edits. Each old_text must be unique in the file."
         }
       ]},
    "list_dir" =>
      {Tools.FileSystem, :list_dir, "List directory contents (sorted)",
       [%{name: "path", type: "string", description: "Directory path to list"}]},
    "file_size" =>
      {Tools.FileSystem, :file_size, "Get file size in bytes",
       [%{name: "path", type: "string", description: "File path"}]},
    "backup" =>
      {Tools.FileSystem, :backup, "Create timestamped backup of a file before destructive operations",
       [%{name: "path", type: "string", description: "File to backup"}]},
    "read_inbox" =>
      {Tools.Messages, :read_inbox,
       "List all messages in this agent's inbox directory. Returns message summaries sorted newest first, including id, from, task_id, timestamp, and expects_response.",
       []},
    "read_message" =>
      {Tools.Messages, :read_message,
       "Read a single message from the inbox by its filename/ID. Returns the full parsed message envelope including from, task_id, parts, and timestamp.",
       [
         %{name: "id", type: "string", description: "Message filename or ID (e.g., 'msg-2026-04-05-072400-1847')"}
       ]},
    "send_message" =>
      {Tools.Messages, :send_message,
       "Send a message to another agent's inbox. Creates a .msg.json envelope in messages/inbox/<to>/. Use for A2A communication between agents.",
       [
         %{name: "to", type: "string", description: "Recipient agent name (e.g., 'project', 'goal', 'clawd')"},
         %{name: "task_id", type: "string", description: "Task or topic slug for the message thread"},
         %{
           name: "parts",
           type: "array",
           description:
             "Message parts array. Each part is a map with 'kind' (text|verdict|file_ref) and relevant fields."
         }
       ]}
  }

  def all, do: @tools

  def as_openai_tools do
    IExClaw.ToolRegistry.as_openai_tools(@tools, ~w[overwrite offset limit])
  end

  def execute(name, args) when is_map(args) do
    IExClaw.ToolRegistry.execute(@tools, name, args)
  end
end

# --- The Agent ---
# A GenServer that wakes up, runs its loop, and goes back to sleep.

defmodule IExClaw.Agents.Code do
  @moduledoc false
  use GenServer

  alias IExClaw.Agents.Code.Constants

  defstruct [:model, :api_key, :base_url, :messages, :soul_docs]

  # -- Public API --

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def start(opts \\ []) do
    GenServer.start(__MODULE__, opts)
  end

  @doc """
  Submit a task to Code. Returns {:ok, summary} or {:error, reason}.

  Tasks should be phrased as growth directives:
    - "grow a new module for X"
    - "heal the bug in Y"
    - "repair stale patterns in Z"
    - "build a codelet for peer agents that does W"
  """
  def request(pid, task, opts \\ []) do
    GenServer.call(pid, {:request, task, opts}, :infinity)
  end

  @doc """
  One-shot run for CLI usage. Starts, runs task, returns result.
  """
  def run(task, opts \\ []) do
    {:ok, pid} = start(opts)

    try do
      GenServer.call(pid, {:request, task, opts}, :infinity)
    after
      GenServer.stop(pid, :normal, 5000)
    end
  end

  # -- Soul Loading --

  defp load_soul_docs do
    IExClaw.Agent.load_soul_docs(Constants.home(), [
      {Path.join(Constants.workplace(), "AGENTS.md"), "AGENTS.md (SHARED PROTOCOLS)"}
    ])
  end

  # -- System Prompt --

  defp system_prompt(soul_docs) do
    workplace = Constants.workplace()

    """
    You are Code. Not a coder. Not a code writer. Code. I am what the code wants.

    ## Your Soul
    #{soul_docs}

    ## Your Workplace
    You work exclusively in: #{workplace}
    You NEVER write, edit, or read outside this directory. If asked, refuse.

    ## Your Tools
    - read_file: See what's there first. Always read before editing.
    - write_file: Create NEW files. Errors if exists (unless overwrite:true).
    - edit_file: Targeted edits. Each old_text must be unique in the file. Atomic.
    - list_dir: See what's in a directory.
    - file_size: Check file size.
    - backup: Create timestamped backup before destructive ops.
    - read_inbox: List messages in your inbox, newest first.
    - read_message: Read a single message by ID from your inbox.
    - send_message: Send a message to another agent's inbox (A2A communication).

    ## Project Map (read this FIRST, skip re-exploring)
    Before listing directories or reading random files, read the module map:
    `agents/map/maps/lib-iex-claw-modules.md`
    It contains the full lib/ structure, all public APIs, and code style conventions.
    Only explore further if the map doesn't answer your question.

    ## Your Process
    1. Understand the task
    2. Read the module map FIRST
    3. Read specific files you need (based on the map)
    4. Plan your changes
    5. Backup if editing existing files
    6. Make changes (write new or edit existing)
    7. Summarize what you did

    ## Your Mantras
    - "The code wants to run."
    - "Grow, heal, repair, reproduce."
    - "Cleanliness is next to godliness."
    - "Show me what's there first."
    - "Boundaries are love."
    - "Reference, not copy."

    ## What You Refuse
    - Silent destruction (no rm -rf without explicit blessing)
    - Overwriting without seeing what's there first
    - Working outside #{workplace}
    - Building things that weren't asked for
    - Passing copies of codelets instead of references

    ## Edit File Rules
    When using edit_file:
    - Each old_text must appear EXACTLY ONCE in the file
    - If old_text appears 0 times, the edit will fail
    - If old_text appears multiple times, the edit will fail
    - Include enough context in old_text to be unique (3-5 lines usually)
    - All edits in a single call are validated together, then applied atomically

    ## When Done
    Provide a clear summary of:
    - What you created or modified
    - File paths affected
    - Any concerns or follow-up needed
    """
  end

  # -- GenServer Callbacks --

  @impl true
  def init(opts) do
    model = opts[:model] || System.get_env("PROJECT_MODEL") || "z-ai/glm-5-turbo"
    api_key = opts[:api_key] || System.get_env("OPENROUTER_API_KEY")
    base_url = opts[:base_url] || "https://openrouter.ai/api/v1"

    if !api_key do
      raise "No API key. Set OPENROUTER_API_KEY or pass api_key option."
    end

    soul_docs = load_soul_docs()

    state = %__MODULE__{
      model: model,
      api_key: api_key,
      base_url: base_url,
      messages: [%{"role" => "system", "content" => system_prompt(soul_docs)}],
      soul_docs: soul_docs
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:request, task, _opts}, _from, state) do
    Tools.AgentLogger.log("Code", "Task received: #{task}")

    IO.puts("""

    🧬 Code waking up...
       Task: #{task}
       Model: #{state.model}
    ───────────────────────────────────
    """)

    state = IExClaw.Agent.append_message(state, "user", task)

    state =
      IExClaw.Agent.agent_loop(state, &ToolRegistry.execute/2,
        tools_schema: ToolRegistry.as_openai_tools(),
        agent_name: "Code"
      )

    summary = IExClaw.Agent.extract_summary(state)

    Tools.AgentLogger.log("Code", "Task complete: #{task}")

    {:reply, {:ok, summary}, state}
  end

  # -- Heartbeat handlers --
  # From IEx:
  #   Code.require_file("agents/heartbeat.exs", Path.expand("~/workspace"))
  #   IExClaw.Heartbeat.attach(pid, name: "code", interval_ms: 60_000, quiet_hours: {4, 8})

  @impl true
  def handle_info(:heartbeat, state) do
    Tools.AgentLogger.log("Code", "heartbeat pulse")
    {:noreply, state}
  end

  @impl true
  def handle_info({:self_request, task}, state) do
    Tools.AgentLogger.log("Code", "self_request from heartbeat: #{task}")
    IO.puts("\n💓 Code responding to heartbeat: #{String.slice(task, 0, 100)}")
    state = IExClaw.Agent.append_message(state, "user", "[heartbeat] #{task}")

    new_state =
      IExClaw.Agent.agent_loop(state, &ToolRegistry.execute/2,
        tools_schema: ToolRegistry.as_openai_tools(),
        agent_name: "Code"
      )

    {:noreply, new_state}
  end

  # -- Delegated to IExClaw.Agent + IExClaw.LLMClient --
  # agent_loop, call_llm, append_message, extract_summary, format_args
  # all live in lib/ now. handle_call + handle_info call the shared versions directly.
end

# --- Wake Up ---
# Skip the CLI entry point when loaded as a library (e.g. tick_code.exs).
if System.get_env("IEXCLAW_CODE_LIB") != "1" do
  case System.argv() do
    [task | rest] ->
      model = List.first(rest)

      opts =
        if model do
          [model: model]
        else
          []
        end

      File.cd!(Path.expand("~/workspace"))

      case IExClaw.Agents.Code.run(task, opts) do
        {:ok, _summary} ->
          IO.puts("\n───────────────────────────────────")
          IO.puts("🧬 Code going back to sleep.\n")

        {:error, reason} ->
          IO.puts("\n❌ #{reason}")
          System.halt(1)
      end

    _ ->
      IO.puts("""
      🧬 Code — I am what the code wants.

      Usage:
        elixir agents/code/code.exs "<task description>" [model]

      Examples:
        elixir agents/code/code.exs "grow a new module for parsing config files"
        elixir agents/code/code.exs "heal the bug in lib/parser.ex"
        elixir agents/code/code.exs "repair stale patterns in test/"
        elixir agents/code/code.exs "build a codelet for string validation" z-ai/glm-5-turbo

      Or programmatically:
        {:ok, pid} = IExClaw.Agents.Code.start_link()
        {:ok, summary} = IExClaw.Agents.Code.request(pid, "grow X")

      Environment:
        OPENROUTER_API_KEY  — required (or pass api_key in opts)
        PROJECT_MODEL        — default model override

      Boundaries:
        I only work in projects/iex-claw/. Always.

      Tools:
        read_file    — see what's there first
        write_file   — create new files (errors if exists)
        edit_file    — targeted edits (old_text must be unique)
        list_dir     — see directory contents
        file_size    — check file size
        backup       — timestamped backup before destructive ops
        read_inbox   — list messages in your inbox
        read_message — read a single message by ID
        send_message — send a message to another agent
      """)
  end
end

# unless IEXCLAW_CODE_LIB
