defmodule IExClaw.ToolRegistryServer do
  @moduledoc """
  A GenServer-backed tool registry with crash isolation and telemetry.

  Tools are registered as definitions and executed via a Task.Supervisor,
  ensuring that a crashing tool never brings down the registry process.

  ## Usage

      {:ok, pid} = IExClaw.ToolRegistryServer.start_link(name: MyRegistry)
      :ok = IExClaw.ToolRegistryServer.register_tool(MyRegistry, :echo, %{
        description: "Echoes input",
        parameters: %{
          type: "object",
          properties: %{input: %{type: "string"}},
          required: ["input"]
        },
        execute: fn params -> {:ok, params["input"]} end
      })
      {:ok, "hello"} = IExClaw.ToolRegistryServer.execute_tool(MyRegistry, :echo, %{"input" => "hello"})
  """

  use GenServer

  @default_timeout 30_000
  @required_keys [:description, :parameters, :execute]

  # --- Client API ---

  @doc "Starts the registry and its Task.Supervisor under :rest_for_one supervision."
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, name, name: name)
  end

  @doc """
  Register a tool definition.

  Returns `:ok` or `{:error, {:invalid_tool_def, missing_keys}}` if the definition
  is missing required keys (`:description`, `:parameters`, `:execute`).
  Returns `{:error, :already_registered}` if a tool with that name exists.
  """
  @spec register_tool(GenServer.server(), atom(), map()) :: :ok | {:error, term()}
  def register_tool(server \\ __MODULE__, name, tool_def) when is_atom(name) and is_map(tool_def) do
    with :ok <- validate_tool_def(tool_def) do
      GenServer.call(server, {:register, name, tool_def})
    end
  end

  @doc "List all registered tool names."
  @spec list_tools(GenServer.server()) :: [atom()]
  def list_tools(server \\ __MODULE__) do
    GenServer.call(server, :list)
  end

  @doc "Describe all registered tools (name, description, parameter schema)."
  @spec describe_tools(GenServer.server()) :: [map()]
  def describe_tools(server \\ __MODULE__) do
    GenServer.call(server, :describe)
  end

  @doc """
  Execute a tool by name with given params.

  Spawns execution under the registry's Task.Supervisor using `async_nolink`.
  Returns `{:ok, result}`, `{:error, :timeout}`, or `{:error, :execution_failed}`.
  """
  @spec execute_tool(GenServer.server(), atom(), map(), keyword()) :: {:ok, any()} | {:error, term()}
  def execute_tool(server \\ __MODULE__, name, params, opts \\ []) when is_atom(name) and is_map(params) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    GenServer.call(server, {:execute, name, params, timeout}, timeout + 5_000)
  end

  @doc """
  Child spec for supervisors.

  Returns a child spec for the ToolRegistryServer GenServer.
  The GenServer internally starts a Task.Supervisor for crash-isolated execution.
  """
  @spec child_spec(keyword()) :: :supervisor.child_spec()
  def child_spec(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    %{
      id: name,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  @doc false
  @spec task_supervisor_name(atom()) :: atom()
  def task_supervisor_name(registry_name) when is_atom(registry_name), do: Module.concat(registry_name, TaskSupervisor)

  @doc false
  @spec task_supervisor_name(pid()) :: nil
  def task_supervisor_name(_pid), do: nil

  # --- Callbacks ---

  @impl true
  def init(name) do
    task_sup_name = task_supervisor_name(name)

    case Task.Supervisor.start_link(name: task_sup_name) do
      {:ok, _pid} ->
        {:ok, %{name: name, tools: %{}}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:register, name, tool_def}, _from, state) do
    if Map.has_key?(state.tools, name) do
      {:reply, {:error, :already_registered}, state}
    else
      :telemetry.execute(
        [:tool_registry, :tool_registered],
        %{duration: 0},
        %{tool_name: name}
      )

      {:reply, :ok, put_in(state.tools[name], tool_def)}
    end
  end

  def handle_call(:list, _from, state) do
    {:reply, Map.keys(state.tools), state}
  end

  def handle_call(:describe, _from, state) do
    descriptions =
      Enum.map(state.tools, fn {name, defn} ->
        %{
          name: name,
          description: defn.description,
          parameters: defn.parameters
        }
      end)

    {:reply, descriptions, state}
  end

  def handle_call({:execute, name, params, timeout}, _from, state) do
    case Map.fetch(state.tools, name) do
      {:ok, tool_def} ->
        task_sup = task_supervisor_name(state.name)
        result = run_isolated(task_sup, tool_def.execute, params, timeout)
        {:reply, result, state}

      :error ->
        {:reply, {:error, :unknown_tool}, state}
    end
  end

  # --- Private ---

  defp validate_tool_def(tool_def) do
    missing = Enum.filter(@required_keys, &(not Map.has_key?(tool_def, &1)))

    if missing == [] do
      if is_function(tool_def[:execute]) do
        :ok
      else
        {:error, {:invalid_tool_def, [:execute_must_be_function]}}
      end
    else
      {:error, {:invalid_tool_def, missing}}
    end
  end

  defp run_isolated(task_sup, execute_fn, params, timeout) do
    start_time = System.monotonic_time()

    task =
      Task.Supervisor.async_nolink(task_sup, fn ->
        execute_fn.(params)
      end)

    result =
      case Task.yield(task, timeout) || Task.shutdown(task) do
        {:ok, {:ok, value}} ->
          emit_success_telemetry(start_time, :ok, value)
          {:ok, value}

        {:ok, {:error, reason}} ->
          emit_error_telemetry(start_time, reason)
          {:error, reason}

        {:exit, _reason} ->
          emit_error_telemetry(start_time, :execution_failed)
          {:error, :execution_failed}

        nil ->
          emit_error_telemetry(start_time, :timeout)
          {:error, :timeout}
      end

    result
  end

  defp emit_success_telemetry(start_time, status, result) do
    :telemetry.execute(
      [:tool_registry, :tool_executed],
      %{duration: System.monotonic_time() - start_time},
      %{tool_name: nil, status: status, result: result}
    )
  end

  defp emit_error_telemetry(start_time, status) do
    :telemetry.execute(
      [:tool_registry, :tool_executed],
      %{duration: System.monotonic_time() - start_time},
      %{tool_name: nil, status: status}
    )
  end
end
