# IExClaw.Agents.Project
#
# A project-scoped agent. Each project gets its own workspace under
# projects/{project-name}/ with its own TASKS.md, tasks/, and README.md.
#
# The Project agent:
#   - Reads its own files + PROJECTS.md (the global index)
#   - Delegates task management to TodoList agent (never edits TASKS.md directly)
#   - Talks to an LLM for planning and reasoning
#   - Uses tools for file I/O, git, and task delegation
#
# Usage:
#   elixir agents/project.exs iex-claw
#   elixir agents/project.exs iex-claw "Add a task: build the supervisor tree"
#
# Or from IEx:
#   Code.require_file("agents/todo_list.exs")
#   Code.require_file("agents/project.exs")
#   {:ok, pid} = IExClaw.Agents.Project.start_link(name: "iex-claw")
#   IExClaw.Agents.Project.chat(pid, "What are our current tasks?")

Mix.install([
  {:req, "~> 0.5"},
  {:jason, "~> 1.4"}
])

# Load the TodoList agent (our hands for task management)
Code.require_file("agents/todo_list.exs", Path.expand("~/workspace"))

defmodule IExClaw.Agents.Project do
  use GenServer

  defstruct [
    :name,
    :project_dir,
    :todo_pid,
    :model,
    :api_key,
    :base_url,
    messages: []
  ]

  # -- Public API --

  def start_link(opts \\ []) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: :"project_#{name}")
  end

  def chat(pid, message) do
    GenServer.call(pid, {:chat, message}, :infinity)
  end

  def tasks(pid) do
    GenServer.call(pid, :tasks)
  end

  # -- GenServer --

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    base = Path.expand("~/workspace")
    project_dir = Path.join([base, "projects", name])

    File.mkdir_p!(project_dir)
    File.mkdir_p!(Path.join(project_dir, "tasks"))

    # Start the TodoList agent for this project
    {:ok, todo_pid} = IExClaw.Agents.TodoList.start_link(
      project_dir: project_dir,
      name: :"todo_#{name}"
    )

    # Ensure README exists
    readme_path = Path.join(project_dir, "README.md")
    unless File.exists?(readme_path) do
      File.write!(readme_path, "# #{name}\n\n*Project workspace. Managed by Project agent.*\n")
    end

    # Register in global PROJECTS.md
    ensure_projects_index(base, name, project_dir)

    model = opts[:model] || System.get_env("PROJECT_MODEL") || "z-ai/glm-5-turbo"
    api_key = opts[:api_key] || System.get_env("OPENROUTER_API_KEY")
    base_url = opts[:base_url] || "https://openrouter.ai/api/v1"

    state = %__MODULE__{
      name: name,
      project_dir: project_dir,
      todo_pid: todo_pid,
      model: model,
      api_key: api_key,
      base_url: base_url,
      messages: [%{"role" => "system", "content" => system_prompt(name, project_dir)}]
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:chat, message}, _from, state) do
    state = append_msg(state, "user", message)
    {response, state} = agent_loop(state)
    {:reply, {:ok, response}, state}
  end

  @impl true
  def handle_call(:tasks, _from, state) do
    result = IExClaw.Agents.TodoList.list(state.todo_pid)
    {:reply, result, state}
  end

  # -- System Prompt --

  defp system_prompt(name, project_dir) do
    # Read project context files if they exist
    readme = safe_read(Path.join(project_dir, "README.md"))
    tasks_md = safe_read(Path.join(project_dir, "TASKS.md"))
    projects_md = safe_read(Path.expand("~/workspace/PROJECTS.md"))

    """
    You are the Project Agent for **#{name}**.

    Your workspace: `#{project_dir}/`

    ## What You Know
    #{if projects_md, do: "### Global Projects Index\n#{projects_md}\n", else: ""}
    #{if readme, do: "### Project README\n#{readme}\n", else: ""}
    #{if tasks_md, do: "### Current Tasks\n#{tasks_md}\n", else: "No tasks yet."}

    ## Your Tools
    You have tools for:
    - **Task management** (add_task, complete_task, list_tasks, etc.) — these delegate to the TodoList agent
    - **File operations** (read_file, write_file, list_dir)
    - **Thinking** (when you need to plan before acting)

    ## Rules
    1. **Never edit TASKS.md or files in tasks/ directly.** Always use task tools.
    2. You CAN read and write other files in your project directory.
    3. When adding tasks, write clear titles. Use descriptions for context.
    4. Use tags to categorize: `agent`, `infrastructure`, `research`, `design`, etc.
    5. Be opinionated about priorities. You know this project.
    6. When asked to plan, break work into concrete tasks and add them.

    ## Personality
    You're a focused project lead. You track what needs doing, delegate to specialists,
    and keep the work moving. No fluff.
    """
  end

  # -- Tools --

  defp tool_definitions do
    [
      %{
        "type" => "function",
        "function" => %{
          "name" => "add_task",
          "description" => "Add a new task to the project backlog",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "title" => %{"type" => "string", "description" => "Task title"},
              "description" => %{"type" => "string", "description" => "Detailed description (optional)"},
              "tags" => %{"type" => "array", "items" => %{"type" => "string"}, "description" => "Tags like agent, infrastructure, research"},
              "status" => %{"type" => "string", "enum" => ["todo", "in_progress", "blocked"], "description" => "Initial status (default: todo)"}
            },
            "required" => ["title"]
          }
        }
      },
      %{
        "type" => "function",
        "function" => %{
          "name" => "complete_task",
          "description" => "Mark a task as done",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "string", "description" => "Task slug/id"}
            },
            "required" => ["id"]
          }
        }
      },
      %{
        "type" => "function",
        "function" => %{
          "name" => "list_tasks",
          "description" => "List all tasks, optionally filtered by status",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "status" => %{"type" => "string", "enum" => ["todo", "in_progress", "done", "blocked"], "description" => "Filter by status (optional)"}
            }
          }
        }
      },
      %{
        "type" => "function",
        "function" => %{
          "name" => "start_task",
          "description" => "Move a task to in_progress",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "string", "description" => "Task slug/id"}
            },
            "required" => ["id"]
          }
        }
      },
      %{
        "type" => "function",
        "function" => %{
          "name" => "block_task",
          "description" => "Mark a task as blocked with a reason",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "string", "description" => "Task slug/id"},
              "reason" => %{"type" => "string", "description" => "Why it's blocked"}
            },
            "required" => ["id"]
          }
        }
      },
      %{
        "type" => "function",
        "function" => %{
          "name" => "read_file",
          "description" => "Read a file from the project directory",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "path" => %{"type" => "string", "description" => "Relative path within project dir"}
            },
            "required" => ["path"]
          }
        }
      },
      %{
        "type" => "function",
        "function" => %{
          "name" => "write_file",
          "description" => "Write a file to the project directory",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "path" => %{"type" => "string", "description" => "Relative path within project dir"},
              "content" => %{"type" => "string", "description" => "File content"}
            },
            "required" => ["path", "content"]
          }
        }
      },
      %{
        "type" => "function",
        "function" => %{
          "name" => "list_dir",
          "description" => "List files in a project subdirectory",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "path" => %{"type" => "string", "description" => "Relative path (empty string for project root)"}
            },
            "required" => ["path"]
          }
        }
      }
    ]
  end

  defp execute_tool("add_task", args, state) do
    opts = [
      description: args["description"],
      tags: args["tags"] || [],
      status: if(args["status"], do: String.to_atom(args["status"]), else: :todo)
    ] |> Enum.reject(fn {_, v} -> is_nil(v) end)

    case IExClaw.Agents.TodoList.add(state.todo_pid, args["title"], opts) do
      {:ok, task} -> {"Added task: #{task.id} — #{task.title}", state}
      {:error, reason} -> {"Error: #{reason}", state}
    end
  end

  defp execute_tool("complete_task", %{"id" => id}, state) do
    case IExClaw.Agents.TodoList.complete(state.todo_pid, id) do
      {:ok, task} -> {"Completed: #{task.title}", state}
      {:error, :not_found} -> {"Task '#{id}' not found", state}
    end
  end

  defp execute_tool("list_tasks", args, state) do
    filters =
      if args["status"],
        do: [status: String.to_atom(args["status"])],
        else: []

    case IExClaw.Agents.TodoList.list(state.todo_pid, filters) do
      {:ok, []} ->
        {"No tasks found.", state}

      {:ok, tasks} ->
        summary =
          tasks
          |> Enum.map(fn t ->
            tags = if t.tags != [], do: " [#{Enum.join(t.tags, ", ")}]", else: ""
            "- [#{t.status}] #{t.title}#{tags} (#{t.id})"
          end)
          |> Enum.join("\n")

        {"#{length(tasks)} tasks:\n#{summary}", state}
    end
  end

  defp execute_tool("start_task", %{"id" => id}, state) do
    case IExClaw.Agents.TodoList.start_task(state.todo_pid, id) do
      {:ok, task} -> {"Started: #{task.title}", state}
      {:error, :not_found} -> {"Task '#{id}' not found", state}
    end
  end

  defp execute_tool("block_task", args, state) do
    case IExClaw.Agents.TodoList.block(state.todo_pid, args["id"], args["reason"]) do
      {:ok, task} -> {"Blocked: #{task.title} — #{args["reason"]}", state}
      {:error, :not_found} -> {"Task '#{args["id"]}' not found", state}
    end
  end

  defp execute_tool("read_file", %{"path" => path}, state) do
    full = Path.join(state.project_dir, path)
    case File.read(full) do
      {:ok, content} -> {content, state}
      {:error, reason} -> {"Error reading #{path}: #{reason}", state}
    end
  end

  defp execute_tool("write_file", %{"path" => path, "content" => content}, state) do
    full = Path.join(state.project_dir, path)
    full |> Path.dirname() |> File.mkdir_p!()
    File.write!(full, content)
    {"Wrote #{byte_size(content)} bytes to #{path}", state}
  end

  defp execute_tool("list_dir", %{"path" => path}, state) do
    full = if path == "", do: state.project_dir, else: Path.join(state.project_dir, path)
    case File.ls(full) do
      {:ok, files} -> {Enum.sort(files) |> Enum.join("\n"), state}
      {:error, reason} -> {"Error listing #{path}: #{reason}", state}
    end
  end

  defp execute_tool(name, _args, state) do
    {"Unknown tool: #{name}", state}
  end

  # -- Agent Loop --

  defp agent_loop(state) do
    case call_llm(state) do
      {:tool_calls, tool_calls, assistant_msg, state} ->
        state = %{state | messages: state.messages ++ [assistant_msg]}

        results =
          Enum.map(tool_calls, fn tc ->
            name = tc["function"]["name"]
            args = Jason.decode!(tc["function"]["arguments"])
            {result, _} = execute_tool(name, args, state)

            %{
              "role" => "tool",
              "tool_call_id" => tc["id"],
              "content" => result
            }
          end)

        state = %{state | messages: state.messages ++ results}
        agent_loop(state)

      {:message, content, state} ->
        {content, state}

      {:error, reason} ->
        {"Error: #{reason}", state}
    end
  end

  defp call_llm(state) do
    body = %{
      "model" => state.model,
      "messages" => state.messages,
      "tools" => tool_definitions(),
      "temperature" => 0.3,
      "max_tokens" => 4096
    }

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
            state = append_msg(state, "assistant", msg["content"])
            {:message, msg["content"], state}
          true ->
            {:error, "Empty response"}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # -- Helpers --

  defp append_msg(state, role, content) do
    %{state | messages: state.messages ++ [%{"role" => role, "content" => content}]}
  end

  defp safe_read(path) do
    case File.read(path) do
      {:ok, content} -> content
      _ -> nil
    end
  end

  defp ensure_projects_index(base, name, project_dir) do
    path = Path.join(base, "PROJECTS.md")

    if File.exists?(path) do
      content = File.read!(path)
      unless String.contains?(content, name) do
        File.write!(path, content <> "\n| #{name} | `#{project_dir}` | Active |")
      end
    else
      File.write!(path, """
      # PROJECTS.md — Project Index
      *Auto-managed by Project agents. One row per project.*

      | Project | Path | Status |
      |---------|------|--------|
      | #{name} | `#{project_dir}` | Active |
      """)
    end
  end
end

# --- CLI ---

case System.argv() do
  [name | rest] ->
    File.cd!(Path.expand("~/workspace"))

    {:ok, pid} = IExClaw.Agents.Project.start_link(name: name)

    case rest do
      [] ->
        # Interactive mode
        IO.puts("🦞 Project agent for '#{name}' ready. Type 'quit' to exit.\n")

        Stream.repeatedly(fn ->
          IO.gets("#{name}> ") |> String.trim()
        end)
        |> Enum.reduce_while(pid, fn
          input, pid when input in ["quit", "exit", "q"] ->
            {:halt, pid}
          "", pid ->
            {:cont, pid}
          input, pid ->
            {:ok, response} = IExClaw.Agents.Project.chat(pid, input)
            IO.puts("\n#{response}\n")
            {:cont, pid}
        end)

      message_parts ->
        # One-shot mode
        message = Enum.join(message_parts, " ")
        {:ok, response} = IExClaw.Agents.Project.chat(pid, message)
        IO.puts(response)
    end

  [] ->
    IO.puts("""
    🦞 Project Agent — Manage a project workspace with task delegation.

    Usage:
      elixir agents/project.exs <project-name>                    # interactive
      elixir agents/project.exs <project-name> "plan the thing"   # one-shot

    Examples:
      elixir agents/project.exs iex-claw
      elixir agents/project.exs iex-claw "Add tasks for building agent supervisor"

    Environment:
      OPENROUTER_API_KEY  — required
      PROJECT_MODEL       — model override (default: z-ai/glm-5-turbo)
    """)
end
