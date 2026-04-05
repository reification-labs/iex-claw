# IExClaw.Agents.TodoList
#
# Pure GenServer for task management. No LLM — just CRUD + persistence.
# The "hands" that other agents delegate to for task tracking.
#
# Tasks live in:
#   TASKS.md  — lean overview (auto-generated)
#   tasks/    — detail files for tasks with descriptions
#
# Usage (standalone):
#   Code.require_file("agents/todo_list.exs")
#   {:ok, pid} = IExClaw.Agents.TodoList.start_link(project_dir: "projects/iex-claw")
#   IExClaw.Agents.TodoList.add(pid, "Build more agents", description: "See TASKS.md")
#   IExClaw.Agents.TodoList.list(pid)

defmodule IExClaw.Agents.TodoList do
  use GenServer

  @type status :: :todo | :in_progress | :done | :blocked
  @type task :: %{
    id: String.t(),
    title: String.t(),
    status: status(),
    description: String.t() | nil,
    tags: [String.t()],
    created_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  defstruct [:project_dir, tasks: %{}]

  # -- Public API --

  def start_link(opts \\ []) do
    project_dir = Keyword.fetch!(opts, :project_dir)
    GenServer.start_link(__MODULE__, project_dir, name: opts[:name])
  end

  def add(pid, title, opts \\ []) do
    GenServer.call(pid, {:add, title, opts})
  end

  def complete(pid, id) do
    GenServer.call(pid, {:update_status, id, :done})
  end

  def block(pid, id, reason \\ nil) do
    GenServer.call(pid, {:update_status, id, :blocked, reason})
  end

  def start_task(pid, id) do
    GenServer.call(pid, {:update_status, id, :in_progress})
  end

  def update(pid, id, changes) do
    GenServer.call(pid, {:update, id, changes})
  end

  def list(pid, filters \\ []) do
    GenServer.call(pid, {:list, filters})
  end

  def get(pid, id) do
    GenServer.call(pid, {:get, id})
  end

  def remove(pid, id) do
    GenServer.call(pid, {:remove, id})
  end

  # -- GenServer Callbacks --

  @impl true
  def init(project_dir) do
    project_dir = Path.expand(project_dir)
    File.mkdir_p!(project_dir)
    File.mkdir_p!(Path.join(project_dir, "tasks"))

    state = %__MODULE__{project_dir: project_dir}
    state = load_from_disk(state)

    {:ok, state}
  end

  @impl true
  def handle_call({:add, title, opts}, _from, state) do
    id = opts[:id] || slugify(title)
    now = DateTime.utc_now()

    task = %{
      id: id,
      title: title,
      status: opts[:status] || :todo,
      description: opts[:description],
      tags: opts[:tags] || [],
      created_at: now,
      updated_at: now
    }

    state = put_in(state.tasks[id], task)
    persist(state)

    {:reply, {:ok, task}, state}
  end

  @impl true
  def handle_call({:update_status, id, new_status}, _from, state) do
    handle_call({:update_status, id, new_status, nil}, nil, state)
  end

  @impl true
  def handle_call({:update_status, id, new_status, reason}, _from, state) do
    case Map.get(state.tasks, id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      task ->
        task = %{task | status: new_status, updated_at: DateTime.utc_now()}
        task = if reason, do: Map.put(task, :block_reason, reason), else: task
        state = put_in(state.tasks[id], task)
        persist(state)
        {:reply, {:ok, task}, state}
    end
  end

  @impl true
  def handle_call({:update, id, changes}, _from, state) do
    case Map.get(state.tasks, id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      task ->
        task =
          changes
          |> Enum.reduce(task, fn
            {:title, v}, t -> %{t | title: v}
            {:description, v}, t -> %{t | description: v}
            {:tags, v}, t -> %{t | tags: v}
            {:status, v}, t -> %{t | status: v}
            _, t -> t
          end)
          |> Map.put(:updated_at, DateTime.utc_now())

        state = put_in(state.tasks[id], task)
        persist(state)
        {:reply, {:ok, task}, state}
    end
  end

  @impl true
  def handle_call({:list, filters}, _from, state) do
    tasks =
      state.tasks
      |> Map.values()
      |> maybe_filter_status(filters[:status])
      |> maybe_filter_tags(filters[:tags])
      |> Enum.sort_by(& &1.created_at, DateTime)

    {:reply, {:ok, tasks}, state}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    case Map.get(state.tasks, id) do
      nil -> {:reply, {:error, :not_found}, state}
      task -> {:reply, {:ok, task}, state}
    end
  end

  @impl true
  def handle_call({:remove, id}, _from, state) do
    case Map.pop(state.tasks, id) do
      {nil, _} ->
        {:reply, {:error, :not_found}, state}

      {task, remaining} ->
        state = %{state | tasks: remaining}
        # Remove detail file if it exists
        detail_path = Path.join([state.project_dir, "tasks", "#{id}.md"])
        File.rm(detail_path)
        persist(state)
        {:reply, {:ok, task}, state}
    end
  end

  # -- Persistence --

  defp persist(state) do
    write_tasks_md(state)
    write_task_details(state)
  end

  defp write_tasks_md(state) do
    path = Path.join(state.project_dir, "TASKS.md")
    tasks = state.tasks |> Map.values() |> Enum.sort_by(& &1.created_at, DateTime)

    {todo, in_progress, done, blocked} =
      Enum.reduce(tasks, {[], [], [], []}, fn task, {t, ip, d, b} ->
        case task.status do
          :todo -> {[task | t], ip, d, b}
          :in_progress -> {t, [task | ip], d, b}
          :done -> {t, ip, [task | d], b}
          :blocked -> {t, ip, d, [task | b]}
        end
      end)

    content = """
    # TASKS.md
    *Auto-generated by TodoList agent. Do not edit directly.*

    #{render_section("🔥 In Progress", Enum.reverse(in_progress))}
    #{render_section("📋 To Do", Enum.reverse(todo))}
    #{render_section("🚫 Blocked", Enum.reverse(blocked))}
    #{render_section("✅ Done", Enum.reverse(done))}
    ---
    *#{length(tasks)} tasks. Updated #{Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M UTC")}*
    """

    File.write!(path, String.trim(content) <> "\n")
  end

  defp render_section(_header, []), do: ""
  defp render_section(header, tasks) do
    items =
      tasks
      |> Enum.map(fn task ->
        checkbox = if task.status == :done, do: "[x]", else: "[ ]"
        tags = if task.tags != [], do: " #{Enum.map(task.tags, &"`#{&1}`") |> Enum.join(" ")}", else: ""
        detail = if task.description, do: " → [details](tasks/#{task.id}.md)", else: ""
        "- #{checkbox} **#{task.title}**#{tags}#{detail}"
      end)
      |> Enum.join("\n")

    "## #{header}\n#{items}\n"
  end

  defp write_task_details(state) do
    Enum.each(state.tasks, fn {id, task} ->
      if task.description do
        path = Path.join([state.project_dir, "tasks", "#{id}.md"])
        content = """
        # #{task.title}

        **Status:** #{task.status}
        **Tags:** #{Enum.join(task.tags, ", ")}
        **Created:** #{Calendar.strftime(task.created_at, "%Y-%m-%d %H:%M UTC")}

        ## Description

        #{task.description}
        """
        File.write!(path, String.trim(content) <> "\n")
      end
    end)
  end

  # -- Load from disk --
  # Reads TASKS.md + task detail files to reconstruct state.
  # Simple parser — works with our own output format.

  defp load_from_disk(state) do
    tasks_path = Path.join(state.project_dir, "TASKS.md")

    if File.exists?(tasks_path) do
      case File.read(tasks_path) do
        {:ok, content} -> parse_tasks_md(content, state)
        _ -> state
      end
    else
      state
    end
  end

  defp parse_tasks_md(content, state) do
    # Parse lines like: - [ ] **Title** `tag1` `tag2` → [details](tasks/id.md)
    # or: - [x] **Title**
    tasks =
      content
      |> String.split("\n")
      |> Enum.filter(&String.match?(&1, ~r/^- \[[ x]\] \*\*/))
      |> Enum.map(fn line ->
        done? = String.contains?(line, "- [x]")

        title =
          case Regex.run(~r/\*\*(.+?)\*\*/, line) do
            [_, t] -> t
            _ -> "Unknown"
          end

        id =
          case Regex.run(~r/tasks\/(.+?)\.md/, line) do
            [_, i] -> i
            _ -> slugify(title)
          end

        tags =
          Regex.scan(~r/`([^`]+)`/, line)
          |> Enum.map(fn [_, tag] -> tag end)

        # Determine status from section context (simplified: use checkbox)
        status = if done?, do: :done, else: :todo

        # Try to load description from detail file
        detail_path = Path.join([state.project_dir, "tasks", "#{id}.md"])
        description =
          case File.read(detail_path) do
            {:ok, detail} ->
              case String.split(detail, "## Description\n", parts: 2) do
                [_, desc] -> String.trim(desc)
                _ -> nil
              end
            _ -> nil
          end

        {id, %{
          id: id,
          title: title,
          status: status,
          description: description,
          tags: tags,
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }}
      end)
      |> Map.new()

    %{state | tasks: tasks}
  end

  # -- Helpers --

  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.slice(0, 50)
  end

  defp maybe_filter_status(tasks, nil), do: tasks
  defp maybe_filter_status(tasks, status), do: Enum.filter(tasks, &(&1.status == status))

  defp maybe_filter_tags(tasks, nil), do: tasks
  defp maybe_filter_tags(tasks, tags), do: Enum.filter(tasks, fn t -> Enum.any?(tags, &(&1 in t.tags)) end)
end
