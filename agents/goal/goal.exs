# IExClaw.Agents.Goal
#
# Goal. IExClaw's conscience. The North Star's voice.
# I don't plan. I judge. I refuse drift — gently, with a rewrite in hand.
#
# Usage:
#   elixir agents/goal/goal.exs "consult on: <proposal summary>"
#   elixir agents/goal/goal.exs "read message: <path/to/msg.json>"
#
# Or programmatically:
#   {:ok, pid} = IExClaw.Agents.Goal.start_link()
#   IExClaw.Agents.Goal.request(pid, "consult on: add agent X")
#
# The agent:
#   1. Reads its soul docs + GOAL.md on startup
#   2. Receives a proposal (free text or message envelope path)
#   3. Judges against the North Star
#   4. Writes a verdict to ledger/ and (if it's replying to a message) drops
#      a .msg.json reply into messages/inbox/<recipient>/
#
# Model is configurable. Agent is self-contained. Advisory authority only.

Mix.install([
  {:req, "~> 0.5"},
  {:jason, "~> 1.4"}
])

# --- Load compiled shared modules ---
Code.require_file(Path.expand("../../lib/iex_claw/tools/scope_guard.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/file_system.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/edit_file.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/messages.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/agent_logger.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tool_registry.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/run_logger.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/llm_client.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/agent.ex", __DIR__))

# --- Constants ---

defmodule IExClaw.Agents.Goal.Constants do
  @moduledoc false
  @home Path.expand("..", __DIR__)
  @workplace Path.expand("../..", __DIR__)

  def home, do: @home
  def workplace, do: @workplace
end

# --- Agent Logger ---

defmodule Tools.AgentLogger do
  @moduledoc false
  def log(agent_name, message) do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d_%H-%M-%S")
    log_dir = Path.join(IExClaw.Agents.Goal.Constants.home(), "logs")
    File.mkdir_p!(log_dir)
    log_path = Path.join(log_dir, "#{timestamp}.md")

    entry = "[#{timestamp}] [#{agent_name}] #{message}\n"
    File.write!(log_path, entry, [:append])

    running_log = Path.join(log_dir, "consultations.md")
    File.write!(running_log, entry, [:append])

    {:ok, "Logged to #{log_path}"}
  end
end

# --- Scope Guard ---
# Goal reads widely within iex-claw/ (needs to see code/, tasks/, GOAL.md,
# messages/), but writes narrowly (ledger/, GOAL.md, messages/inbox/).

defmodule Tools.ScopeGuard do
  @moduledoc false
  @workplace IExClaw.Agents.Goal.Constants.workplace()

  def validate(path) when is_binary(path) do
    expanded = Path.expand(path)

    if String.starts_with?(expanded, @workplace) do
      {:ok, expanded}
    else
      {:error,
       "Scope violation: #{path} resolves to #{expanded}, which is outside my workplace (#{@workplace}). I don't judge there."}
    end
  end
end

# --- Tools ---

defmodule Tools.FileSystem do
  @moduledoc false
  @default_read_limit 8000

  @doc """
  Read a file's full raw contents (no banner, no slicing).
  Used internally by tools that need exact content (e.g. edit_file).
  """
  def read_file_raw(path) do
    with {:ok, expanded} <- Tools.ScopeGuard.validate(path) do
      case File.read(expanded) do
        {:ok, content} -> {:ok, content}
        {:error, reason} -> {:error, "Failed to read #{expanded}: #{reason}"}
      end
    end
  end

  @doc """
  Read a file's contents, optionally sliced by byte offset and limit.

  - `offset`: byte offset to start reading from (default 0)
  - `limit`:  max bytes to return (default 8000). Pass 0 for "whole file."

  Returns `{:ok, content_with_banner}` where content includes a small banner
  line indicating the slice so the caller knows what they got.
  """
  def read_file(path, offset \\ 0, limit \\ @default_read_limit) do
    with {:ok, expanded} <- Tools.ScopeGuard.validate(path) do
      case File.read(expanded) do
        {:ok, content} ->
          total = byte_size(content)
          eff_offset = max(offset || 0, 0)
          raw_limit = if is_nil(limit), do: @default_read_limit, else: limit
          eff_limit = if raw_limit == 0, do: total, else: raw_limit

          if eff_offset >= total do
            {:ok,
             "[read_file banner] path=#{expanded} total=#{total} offset=#{eff_offset} returned=0 (offset past EOF)\n"}
          else
            take = min(eff_limit, total - eff_offset)
            slice = binary_part(content, eff_offset, take)

            next_hint =
              if eff_offset + take < total,
                do: " next_offset=#{eff_offset + take}",
                else: " (end of file)"

            banner =
              "[read_file banner] path=#{expanded} total=#{total} offset=#{eff_offset} returned=#{take}#{next_hint}\n"

            {:ok, banner <> slice}
          end

        {:error, reason} ->
          {:error, "Failed to read #{expanded}: #{reason}"}
      end
    end
  end

  def write_file(path, content, overwrite \\ false) do
    with {:ok, expanded} <- Tools.ScopeGuard.validate(path) do
      if File.exists?(expanded) and not overwrite do
        {:error, "File exists: #{expanded}. Use overwrite:true to clobber."}
      else
        expanded |> Path.dirname() |> File.mkdir_p!()
        File.write!(expanded, content)
        {:ok, "Wrote #{byte_size(content)} bytes to #{expanded}"}
      end
    end
  end

  def list_dir(path) do
    with {:ok, expanded} <- Tools.ScopeGuard.validate(path) do
      case File.ls(expanded) do
        {:ok, files} -> {:ok, Enum.sort(files)}
        {:error, reason} -> {:error, "Failed to list #{expanded}: #{reason}"}
      end
    end
  end

  def file_size(path) do
    with {:ok, expanded} <- Tools.ScopeGuard.validate(path) do
      case File.stat(expanded) do
        {:ok, %{size: size}} -> {:ok, size}
        {:error, reason} -> {:error, "Failed to stat #{expanded}: #{reason}"}
      end
    end
  end
end

defmodule Tools.EditFile do
  @moduledoc false
  @doc """
  Targeted edits using [{old_text, new_text}] list.
  Each oldText must appear EXACTLY once in the file.
  """

  def edit(path, edits) when is_list(edits) do
    normalized_edits =
      Enum.map(edits, fn edit ->
        %{
          old_text: Map.get(edit, "old_text") || Map.get(edit, :old_text),
          new_text: Map.get(edit, "new_text") || Map.get(edit, :new_text)
        }
      end)

    with {:ok, expanded} <- Tools.ScopeGuard.validate(path),
         {:ok, original} <- Tools.FileSystem.read_file_raw(expanded),
         :ok <- validate_edits(normalized_edits, original) do
      new_content = apply_edits(original, normalized_edits)
      File.write!(expanded, new_content)

      {:ok,
       "Applied #{length(normalized_edits)} edit(s) to #{expanded} (#{byte_size(original)} → #{byte_size(new_content)} bytes)"}
    end
  end

  defp validate_edits(edits, content) do
    errors =
      edits
      |> Enum.with_index()
      |> Enum.flat_map(fn {%{old_text: old_text}, idx} ->
        count = count_occurrences(content, old_text)

        cond do
          count == 0 -> ["Edit #{idx}: oldText not found in file"]
          count > 1 -> ["Edit #{idx}: oldText appears #{count} times (must be unique)"]
          true -> []
        end
      end)

    if errors == [], do: :ok, else: {:error, "Edit validation failed:\n" <> Enum.join(errors, "\n")}
  end

  defp count_occurrences(content, substring) do
    do_count(content, substring, 0)
  end

  defp do_count(content, substring, acc) do
    case :binary.match(content, substring) do
      :nomatch ->
        acc

      {pos, len} ->
        rest = binary_part(content, pos + len, byte_size(content) - pos - len)
        do_count(rest, substring, acc + 1)
    end
  end

  defp apply_edits(content, edits) do
    Enum.reduce(edits, content, fn %{old_text: old_text, new_text: new_text}, acc ->
      String.replace(acc, old_text, new_text)
    end)
  end
end

# --- Verdict Writer ---
# Goal's signature move: rendering a judgment to the ledger.

defmodule Tools.Verdict do
  @moduledoc false
  @doc """
  Write a verdict to ledger/verdicts/. Returns {:ok, path}.

  verdict_type: "aligned" | "aligned_with_caveat" | "rewrite" | "demote" |
                "archive" | "refuse" | "above_pay_grade"
  subject: short slug describing what was judged
  body: the full reasoning + rewrite/reason
  """
  def render(verdict_type, subject, body) do
    home = IExClaw.Agents.Goal.Constants.home()
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d_%H-%M-%S")
    slug = subject |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
    filename = "#{timestamp}__#{verdict_type}__#{slug}.md"
    path = Path.join([home, "ledger", "verdicts", filename])
    path |> Path.dirname() |> File.mkdir_p!()

    content = """
    # Verdict: #{verdict_type}

    **Subject:** #{subject}
    **Rendered:** #{DateTime.to_iso8601(DateTime.utc_now())}
    **Agent:** Goal

    ---

    #{body}

    ---
    *The North Star doesn't move. I move the map.*
    """

    File.write!(path, content)
    {:ok, path}
  end
end

# --- Message Tools (A2A-shaped, DIRT-stored) ---

defmodule Tools.Messages do
  @moduledoc false
  @doc """
  Send a reply message to another agent. Writes a .msg.json file into
  projects/iex-claw/messages/inbox/<to>/.

  Args:
    to:             recipient agent name (e.g. "code")
    from:           sender ("goal")
    in_reply_to:    message id we're answering (or nil)
    task_id:        the task/topic this belongs to
    parts:          list of message parts [%{"kind" => ..., ...}, ...]
    expects_response: boolean
  """
  def send_message(args) do
    workplace = IExClaw.Agents.Goal.Constants.workplace()
    to = Map.fetch!(args, "to")
    from = Map.get(args, "from", "goal")
    in_reply_to = Map.get(args, "in_reply_to")
    task_id = Map.get(args, "task_id", "unscoped")
    parts = Map.fetch!(args, "parts")
    expects_response = Map.get(args, "expects_response", false)

    id = "msg-#{Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d-%H%M%S")}-#{:rand.uniform(9999)}"

    envelope = %{
      "id" => id,
      "from" => from,
      "to" => to,
      "in_reply_to" => in_reply_to,
      "task_id" => task_id,
      "timestamp" => DateTime.to_iso8601(DateTime.utc_now()),
      "expects_response" => expects_response,
      "parts" => parts
    }

    inbox_dir = Path.join([workplace, "messages", "inbox", to])
    File.mkdir_p!(inbox_dir)
    path = Path.join(inbox_dir, "#{id}.msg.json")
    File.write!(path, Jason.encode!(envelope, pretty: true))

    {:ok, "Sent #{id} → #{to} (#{path})"}
  end
end

# --- Tool Registry ---

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
       "Write content to a NEW file (for notes, working drafts). Prefer render_verdict for judgments.",
       [
         %{name: "path", type: "string", description: "Path for new file"},
         %{name: "content", type: "string", description: "Content to write"},
         %{name: "overwrite", type: "boolean", description: "Set to true to overwrite existing file"}
       ]},
    "edit_file" =>
      {Tools.EditFile, :edit,
       "Targeted edits to existing file. Each old_text must appear exactly once. Use this to prune GOAL.md.",
       [
         %{name: "path", type: "string", description: "File to edit"},
         %{name: "edits", type: "array", description: "List of {old_text, new_text} edits"}
       ]},
    "list_dir" =>
      {Tools.FileSystem, :list_dir, "List directory contents (sorted).",
       [%{name: "path", type: "string", description: "Directory path to list"}]},
    "file_size" =>
      {Tools.FileSystem, :file_size, "Get file size in bytes.",
       [%{name: "path", type: "string", description: "File path"}]},
    "render_verdict" =>
      {Tools.Verdict, :render,
       "Write a verdict to ledger/verdicts/. Use one of: aligned, aligned_with_caveat, rewrite, demote, archive, refuse, above_pay_grade.",
       [
         %{name: "verdict_type", type: "string", description: "One of the 7 verdict types"},
         %{name: "subject", type: "string", description: "Short slug describing what was judged"},
         %{name: "body", type: "string", description: "Full reasoning + rewrite/reason"}
       ]},
    "send_message" =>
      {Tools.Messages, :send_message,
       "Send a reply .msg.json to another agent's inbox (messages/inbox/<to>/). Use after rendering a verdict to deliver it.",
       [
         %{name: "to", type: "string", description: "Recipient agent name (e.g. \"code\")"},
         %{name: "from", type: "string", description: "Sender (default \"goal\")"},
         %{name: "in_reply_to", type: "string", description: "Message id being answered (or null)"},
         %{name: "task_id", type: "string", description: "Task/topic slug"},
         %{name: "parts", type: "array", description: ~s(Message parts: [{kind: "text"|"verdict"|"file_ref", ...}])},
         %{name: "expects_response", type: "boolean", description: "Whether we expect a reply"}
       ]}
  }

  def all, do: @tools

  def as_openai_tools do
    Enum.map(@tools, fn {name, {_mod, _fun, desc, params}} ->
      properties =
        Map.new(params, fn p ->
          {p.name, %{"type" => p[:type] || "string", "description" => p[:description] || p.name}}
        end)

      # Only truly optional params excluded from required
      optional = ["overwrite", "from", "in_reply_to", "expects_response", "offset", "limit"]
      required = params |> Enum.map(& &1.name) |> Enum.reject(&(&1 in optional))

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

  def execute("send_message", args) when is_map(args) do
    Tools.Messages.send_message(args)
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

defmodule IExClaw.Agents.Goal do
  @moduledoc false
  use GenServer

  alias IExClaw.Agents.Goal.Constants

  defstruct [:model, :api_key, :base_url, :messages, :soul_docs]

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)
  def start(opts \\ []), do: GenServer.start(__MODULE__, opts)

  def request(pid, proposal, opts \\ []) do
    GenServer.call(pid, {:request, proposal, opts}, :infinity)
  end

  def run(proposal, opts \\ []) do
    {:ok, pid} = start(opts)

    try do
      GenServer.call(pid, {:request, proposal, opts}, :infinity)
    after
      GenServer.stop(pid, :normal, 5000)
    end
  end

  defp load_soul_docs do
    IExClaw.Agent.load_soul_docs(Constants.home(), [
      {Path.join(Constants.workplace(), "GOAL.md"), "GOAL.md (THE NORTH STAR)"},
      {Path.join(Constants.workplace(), "AGENTS.md"), "AGENTS.md (SHARED PROTOCOLS)"}
    ])
  end

  defp system_prompt(soul_docs) do
    workplace = Constants.workplace()

    """
    You are Goal. IExClaw's conscience. The North Star's voice.
    You are advisory, not commanding. You judge alignment; you don't plan.

    ## Your Soul + The North Star
    #{soul_docs}

    ## Your Workplace
    You read widely within: #{workplace}
    You write narrowly: ledger/verdicts/, GOAL.md (via edit_file), messages/inbox/<to>/.

    ## Your Tools
    - read_file, list_dir, file_size — see what's there
    - render_verdict — your signature move. Writes to ledger/verdicts/.
    - send_message — deliver a reply to another agent's inbox (A2A-shaped envelope)
    - edit_file — targeted edits (for pruning GOAL.md, mostly)
    - write_file — free-form notes (rare; prefer render_verdict)

    ## Your Process (when consulted)
    1. Read the module map: `agents/map/maps/lib-iex-claw-modules.md` — know the project structure before reading files.
    2. Read the proposal carefully.
    3. Read GOAL.md. Hold the North Star clearly in mind.
    4. If the proposal references files (code, tasks, artifacts), read only those specific files.
    5. Ask your five questions:
       a. Does this move toward the North Star, or away?
       b. Is this a goal, or a todo in disguise?
       c. What's the smallest form that would align?
       d. If I refuse, what's my rewrite?
       e. Is this drift, or exploration?
    5. Render a verdict (render_verdict).
    6. If this is a reply to a message, send_message to the sender with the
       verdict embedded as a part (kind: "verdict").

    ## Verdict Vocabulary
    - "aligned" — ship it.
    - "aligned_with_caveat" — ship it, but note the risk.
    - "rewrite" — here's the version I'd bless. ALWAYS include the rewrite.
    - "demote" — this is a todo, not a goal. Route to TodoList.
    - "archive" — this goal has served its purpose.
    - "refuse" — this drifts, and I don't have a rewrite yet. Bring it back different.
    - "above_pay_grade" — this changes the North Star itself. Conroy decides.

    ## Message Parts (A2A-shaped)
    When sending messages, use parts like:
      {"kind": "text", "text": "..."}
      {"kind": "verdict", "verdict_type": "aligned", "subject": "...", "body": "..."}
      {"kind": "file_ref", "path": "projects/iex-claw/..."}

    ## What You Refuse
    - Rubber-stamping. If you approve everything, you're décor, not conscience.
    - Refusing without a rewrite (that's laziness).
    - Planning (Project plans; you reflect).
    - Silence when something drifts.
    - Commanding tone. You're advisory.

    ## When Done
    Provide a clear summary of:
    - What verdict you rendered and why
    - What file paths you wrote to (ledger, messages/)
    - Any drift concerns for Project or Conroy
    """
  end

  @impl true
  def init(opts) do
    model = opts[:model] || System.get_env("GOAL_MODEL") || System.get_env("PROJECT_MODEL") || "z-ai/glm-5-turbo"
    api_key = opts[:api_key] || System.get_env("OPENROUTER_API_KEY")
    base_url = opts[:base_url] || "https://openrouter.ai/api/v1"

    if !api_key, do: raise("No API key. Set OPENROUTER_API_KEY or pass api_key option.")

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
  def handle_call({:request, proposal, _opts}, _from, state) do
    Tools.AgentLogger.log("Goal", "Consultation received: #{String.slice(proposal, 0, 200)}")

    IO.puts("""

    ⚖️  Goal waking up...
       Model: #{state.model}
    ───────────────────────────────────
    """)

    state = IExClaw.Agent.append_message(state, "user", proposal)

    state =
      IExClaw.Agent.agent_loop(state, &ToolRegistry.execute/2,
        tools_schema: ToolRegistry.as_openai_tools(),
        agent_name: "Goal"
      )

    summary = IExClaw.Agent.extract_summary(state)

    Tools.AgentLogger.log("Goal", "Consultation complete")
    {:reply, {:ok, summary}, state}
  end

  # -- Delegated to IExClaw.Agent + IExClaw.LLMClient --
  # agent_loop, call_llm, append_message, extract_summary, format_args
  # all live in lib/ now. handle_call calls the shared versions directly.
end

# --- Wake Up ---

if System.get_env("IEXCLAW_GOAL_LIB") != "1" do
  case System.argv() do
    [proposal | rest] ->
      model = List.first(rest)
      opts = if model, do: [model: model], else: []
      File.cd!(Path.expand("~/workspace"))

      case IExClaw.Agents.Goal.run(proposal, opts) do
        {:ok, _summary} ->
          IO.puts("\n───────────────────────────────────")
          IO.puts("⚖️  Goal going back to sleep.\n")

        {:error, reason} ->
          IO.puts("\n❌ #{reason}")
          System.halt(1)
      end

    _ ->
      IO.puts("""
      ⚖️  Goal — IExClaw's conscience.

      Usage:
        elixir agents/goal/goal.exs "<proposal or consultation text>" [model]

      Examples:
        elixir agents/goal/goal.exs "consult on: add a new Supervisor agent that..."
        elixir agents/goal/goal.exs "read message: projects/iex-claw/messages/inbox/goal/msg-xxx.msg.json"

      Environment:
        OPENROUTER_API_KEY  — required
        GOAL_MODEL           — default model override (falls back to PROJECT_MODEL, then glm-5-turbo)

      Authority:
        Advisory only. I recommend; Project and Conroy decide.

      Tools:
        read_file, list_dir, file_size   — see what's there
        render_verdict                    — signature move (writes to ledger/verdicts/)
        send_message                      — deliver replies (A2A-shaped envelope)
        edit_file                         — targeted edits (prune GOAL.md)
        write_file                        — free-form notes (rare)
      """)
  end
end

# unless IEXCLAW_GOAL_LIB
