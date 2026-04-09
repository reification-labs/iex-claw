defmodule IExClaw.ToolRegistryServerTest do
  use ExUnit.Case, async: true

  alias IExClaw.ToolRegistryServer

  setup do
    name = :"test_registry_#{System.unique_integer([:positive])}"
    spec = ToolRegistryServer.child_spec(name: name)
    {mod, fun, args} = spec.start
    {:ok, sup_pid} = apply(mod, fun, args)
    on_exit(fn ->
      ref = Process.monitor(sup_pid)
      Process.exit(sup_pid, :shutdown)
      receive do
        {:DOWN, ^ref, _, _, _} -> :ok
      after
        1000 -> :ok
      end
      Process.demonitor(ref, [:flush])
    end)
    {:ok, registry: name, sup_pid: sup_pid}
  end

  describe "register_tool/3" do
    test "registers a valid tool definition", %{registry: reg} do
      assert :ok =
               ToolRegistryServer.register_tool(reg, :greeter, %{
                 description: "Says hello",
                 parameters: %{
                   type: "object",
                   properties: %{"name" => %{"type" => "string"}},
                   required: ["name"]
                 },
                 execute: fn params -> {:ok, "Hello, #{params["name"]}!"} end
               })

      assert :greeter in ToolRegistryServer.list_tools(reg)
    end

    test "rejects duplicate registration", %{registry: reg} do
      defn = %{
        description: "Test",
        parameters: %{type: "object", properties: %{}, required: []},
        execute: fn _ -> {:ok, :ok} end
      }

      assert :ok = ToolRegistryServer.register_tool(reg, :dup, defn)
      assert {:error, :already_registered} = ToolRegistryServer.register_tool(reg, :dup, defn)
    end

    test "rejects missing required keys", %{registry: reg} do
      assert {:error, {:invalid_tool_def, [:description, :execute]}} =
               ToolRegistryServer.register_tool(reg, :bad, %{
                 parameters: %{type: "object", properties: %{}, required: []}
               })
    end

    test "rejects non-function execute", %{registry: reg} do
      assert {:error, {:invalid_tool_def, [:execute_must_be_function]}} =
               ToolRegistryServer.register_tool(reg, :bad, %{
                 description: "Test",
                 parameters: %{type: "object", properties: %{}, required: []},
                 execute: "not a function"
               })
    end
  end

  describe "list_tools/1" do
    test "returns empty list for fresh registry", %{registry: reg} do
      assert ToolRegistryServer.list_tools(reg) == []
    end

    test "returns all registered tool names", %{registry: reg} do
      register_simple(reg, :a)
      register_simple(reg, :b)
      register_simple(reg, :c)

      tools = ToolRegistryServer.list_tools(reg)
      assert length(tools) == 3
    end
  end

  describe "describe_tools/1" do
    test "returns description maps for each tool", %{registry: reg} do
      ToolRegistryServer.register_tool(reg, :adder, %{
        description: "Adds numbers",
        parameters: %{
          "type" => "object",
          "properties" => %{"a" => %{"type" => "integer"}, "b" => %{"type" => "integer"}},
          "required" => ["a", "b"]
        },
        execute: fn _ -> {:ok, 0} end
      })

      [desc] = ToolRegistryServer.describe_tools(reg)
      assert desc.name == :adder
      assert desc.description == "Adds numbers"
      assert desc.parameters["properties"]["a"]["type"] == "integer"
    end
  end

  describe "execute_tool/3" do
    test "executes a registered tool successfully", %{registry: reg} do
      ToolRegistryServer.register_tool(reg, :adder, %{
        description: "Adds numbers",
        parameters: %{
          type: "object",
          properties: %{"a" => %{"type" => "integer"}, "b" => %{"type" => "integer"}},
          required: ["a", "b"]
        },
        execute: fn params -> {:ok, params["a"] + params["b"]} end
      })

      assert {:ok, 7} = ToolRegistryServer.execute_tool(reg, :adder, %{"a" => 3, "b" => 4})
    end

    test "returns error for unknown tool", %{registry: reg} do
      assert {:error, :unknown_tool} = ToolRegistryServer.execute_tool(reg, :nope, %{})
    end

    test "propagates tool errors", %{registry: reg} do
      ToolRegistryServer.register_tool(reg, :failer, %{
        description: "Always fails",
        parameters: %{type: "object", properties: %{}, required: []},
        execute: fn _ -> {:error, :intentional} end
      })

      assert {:error, :intentional} = ToolRegistryServer.execute_tool(reg, :failer, %{})
    end

    test "isolates crashes — registry survives", %{registry: reg} do
      ToolRegistryServer.register_tool(reg, :crasher, %{
        description: "Always crashes",
        parameters: %{type: "object", properties: %{}, required: []},
        execute: fn _ -> raise "boom" end
      })

      assert {:error, :execution_failed} = ToolRegistryServer.execute_tool(reg, :crasher, %{})

      # Registry is still alive and functional
      register_simple(reg, :survivor)
      assert {:ok, :ok} = ToolRegistryServer.execute_tool(reg, :survivor, %{})
    end

    test "times out slow tools", %{registry: reg} do
      ToolRegistryServer.register_tool(reg, :slowpoke, %{
        description: "Very slow",
        parameters: %{type: "object", properties: %{}, required: []},
        execute: fn _ ->
          Process.sleep(10_000)
          {:ok, :done}
        end
      })

      assert {:error, :timeout} =
               ToolRegistryServer.execute_tool(reg, :slowpoke, %{}, timeout: 100)
    end
  end

  describe "telemetry" do
    test "handler receives :registered events", %{registry: reg} do
      # Use an Agent as counter since telemetry fires in the GenServer process
      {:ok, counter} = Agent.start_link(fn -> [] end)
      handler = "test-reg-#{System.unique_integer()}"

      :telemetry.attach(
        handler,
        [:iex_claw, :tool_registry, :registered],
        fn _name, _measurements, metadata, _config ->
          Agent.update(counter, fn events -> [metadata | events] end)
        end,
        nil
      )

      register_simple(reg, :telemetry_tool)

      # Give the GenServer time to process
      Process.sleep(10)
      events = Agent.get(counter, & &1)
      assert [%{tool_name: :telemetry_tool}] = events

      :telemetry.detach(handler)
      Agent.stop(counter)
    end

    test "handler receives :executed events on success with tool_name", %{registry: reg} do
      {:ok, counter} = Agent.start_link(fn -> [] end)
      handler = "test-exec-#{System.unique_integer()}"

      :telemetry.attach(
        handler,
        [:iex_claw, :tool_registry, :executed],
        fn _name, measurements, metadata, _config ->
          Agent.update(counter, fn events -> [{measurements, metadata} | events] end)
        end,
        nil
      )

      ToolRegistryServer.register_tool(reg, :fast, %{
        description: "Fast tool",
        parameters: %{type: "object", properties: %{}, required: []},
        execute: fn _ -> {:ok, :done} end
      })

      assert {:ok, :done} = ToolRegistryServer.execute_tool(reg, :fast, %{})

      Process.sleep(10)
      [{measurements, metadata}] = Agent.get(counter, & &1)
      assert measurements.duration > 0
      assert metadata.tool_name == :fast
      assert metadata.result == :done

      :telemetry.detach(handler)
      Agent.stop(counter)
    end

    test "handler receives :failed events on crash with tool_name", %{registry: reg} do
      {:ok, counter} = Agent.start_link(fn -> [] end)
      handler = "test-crash-#{System.unique_integer()}"

      :telemetry.attach(
        handler,
        [:iex_claw, :tool_registry, :failed],
        fn _name, _measurements, metadata, _config ->
          Agent.update(counter, fn events -> [metadata | events] end)
        end,
        nil
      )

      ToolRegistryServer.register_tool(reg, :crash, %{
        description: "Crash tool",
        parameters: %{type: "object", properties: %{}, required: []},
        execute: fn _ -> raise "nope" end
      })

      assert {:error, :execution_failed} = ToolRegistryServer.execute_tool(reg, :crash, %{})

      Process.sleep(10)
      [metadata] = Agent.get(counter, & &1)
      assert metadata.tool_name == :crash
      assert metadata.reason == :execution_failed

      :telemetry.detach(handler)
      Agent.stop(counter)
    end

    test "handler receives :failed events on tool error with tool_name", %{registry: reg} do
      {:ok, counter} = Agent.start_link(fn -> [] end)
      handler = "test-err-#{System.unique_integer()}"

      :telemetry.attach(
        handler,
        [:iex_claw, :tool_registry, :failed],
        fn _name, _measurements, metadata, _config ->
          Agent.update(counter, fn events -> [metadata | events] end)
        end,
        nil
      )

      ToolRegistryServer.register_tool(reg, :failer, %{
        description: "Fail tool",
        parameters: %{type: "object", properties: %{}, required: []},
        execute: fn _ -> {:error, :boom} end
      })

      assert {:error, :boom} = ToolRegistryServer.execute_tool(reg, :failer, %{})

      Process.sleep(10)
      [metadata] = Agent.get(counter, & &1)
      assert metadata.tool_name == :failer
      assert metadata.reason == :boom

      :telemetry.detach(handler)
      Agent.stop(counter)
    end
  end

  describe "child_spec" do
    test "returns valid child spec with supervisor type" do
      spec = ToolRegistryServer.child_spec(name: :test_spec)
      assert spec.id == :test_spec
      assert spec.type == :supervisor
    end

    test "default name is the module" do
      spec = ToolRegistryServer.child_spec([])
      assert spec.id == ToolRegistryServer
    end
  end

  describe "supervision tree" do
    test "Task.Supervisor is a sibling child, not inside init" do
      name = :"test_sup_tree_#{System.unique_integer([:positive])}"
      spec = ToolRegistryServer.child_spec(name: name)
      {mod, fun, args} = spec.start
      {:ok, sup_pid} = apply(mod, fun, args)
      on_exit(fn ->
        ref = Process.monitor(sup_pid)
        Process.exit(sup_pid, :shutdown)
        receive do
          {:DOWN, ^ref, _, _, _} -> :ok
        after
          1000 -> :ok
        end
        Process.demonitor(ref, [:flush])
      end)

      task_sup_name = ToolRegistryServer.task_supervisor_name(name)

      # The Task.Supervisor should be a direct child of our wrapper supervisor
      children = Supervisor.which_children(sup_pid)

      child_ids = Enum.map(children, fn {id, _pid, _type, _modules} -> id end)
      assert task_sup_name in child_ids
      assert name in child_ids

      # The Task.Supervisor should be alive and reachable by name
      assert Process.whereis(task_sup_name) != nil
    end

    test "rest_for_one: GenServer crash does not kill Task.Supervisor" do
      name = :"test_rfo_#{System.unique_integer([:positive])}"
      spec = ToolRegistryServer.child_spec(name: name)
      {mod, fun, args} = spec.start
      {:ok, sup_pid} = apply(mod, fun, args)
      on_exit(fn ->
        ref = Process.monitor(sup_pid)
        Process.exit(sup_pid, :shutdown)
        receive do
          {:DOWN, ^ref, _, _, _} -> :ok
        after
          1000 -> :ok
        end
        Process.demonitor(ref, [:flush])
      end)

      task_sup_name = ToolRegistryServer.task_supervisor_name(name)

      # Register a tool and verify it works
      ToolRegistryServer.register_tool(name, :echo, %{
        description: "Echo",
        parameters: %{type: "object", properties: %{}, required: []},
        execute: fn _ -> {:ok, :hello} end
      })

      assert {:ok, :hello} = ToolRegistryServer.execute_tool(name, :echo, %{})

      # Find and kill the GenServer process
      children = Supervisor.which_children(sup_pid)

      {^name, gen_pid, :worker, _} =
        Enum.find(children, fn {id, _, _, _} -> id == name end)

      # Capture the Task.Supervisor PID before crash
      {^task_sup_name, task_sup_pid_before, :supervisor, _} =
        Enum.find(children, fn {id, _, _, _} -> id == task_sup_name end)

      # Kill the GenServer
      Process.exit(gen_pid, :kill)

      # Wait for restart
      Process.sleep(100)

      # Task.Supervisor should still be the same process (not restarted)
      children_after = Supervisor.which_children(sup_pid)

      {^task_sup_name, task_sup_pid_after, :supervisor, _} =
        Enum.find(children_after, fn {id, _, _, _} -> id == task_sup_name end)

      assert task_sup_pid_before == task_sup_pid_after

      # GenServer should have restarted (new PID, fresh state)
      {^name, gen_pid_after, :worker, _} =
        Enum.find(children_after, fn {id, _, _, _} -> id == name end)

      assert gen_pid_after != gen_pid

      # Fresh state — tools are gone after restart
      assert ToolRegistryServer.list_tools(name) == []
    end

    test "rest_for_one: Task.Supervisor crash restarts GenServer too" do
      name = :"test_rfo_ts_#{System.unique_integer([:positive])}"
      spec = ToolRegistryServer.child_spec(name: name)
      {mod, fun, args} = spec.start
      {:ok, sup_pid} = apply(mod, fun, args)
      on_exit(fn ->
        ref = Process.monitor(sup_pid)
        Process.exit(sup_pid, :shutdown)
        receive do
          {:DOWN, ^ref, _, _, _} -> :ok
        after
          1000 -> :ok
        end
        Process.demonitor(ref, [:flush])
      end)

      task_sup_name = ToolRegistryServer.task_supervisor_name(name)

      # Register a tool
      ToolRegistryServer.register_tool(name, :echo, %{
        description: "Echo",
        parameters: %{type: "object", properties: %{}, required: []},
        execute: fn _ -> {:ok, :hello} end
      })

      # Find and kill the Task.Supervisor
      children = Supervisor.which_children(sup_pid)

      {^task_sup_name, task_sup_pid, :supervisor, _} =
        Enum.find(children, fn {id, _, _, _} -> id == task_sup_name end)

      Process.exit(task_sup_pid, :kill)

      # Wait for restart cascade
      Process.sleep(100)

      # Both should have restarted (new PIDs)
      children_after = Supervisor.which_children(sup_pid)

      {^task_sup_name, task_sup_pid_after, :supervisor, _} =
        Enum.find(children_after, fn {id, _, _, _} -> id == task_sup_name end)

      {^name, gen_pid_after, :worker, _} =
        Enum.find(children_after, fn {id, _, _, _} -> id == name end)

      assert task_sup_pid_after != task_sup_pid

      # GenServer should also have restarted (rest_for_one)
      assert gen_pid_after != nil

      # Fresh state
      assert ToolRegistryServer.list_tools(name) == []

      # Registry should still be functional after restart
      ToolRegistryServer.register_tool(name, :new_tool, %{
        description: "New",
        parameters: %{type: "object", properties: %{}, required: []},
        execute: fn _ -> {:ok, :works} end
      })

      assert {:ok, :works} = ToolRegistryServer.execute_tool(name, :new_tool, %{})
    end
  end

  describe "unregister_tool/2" do
    test "removes a registered tool", %{registry: reg} do
      register_simple(reg, :to_remove)
      assert :to_remove in ToolRegistryServer.list_tools(reg)
      assert :ok = ToolRegistryServer.unregister_tool(reg, :to_remove)
      assert :to_remove not in ToolRegistryServer.list_tools(reg)
    end

    test "returns error for unknown tool", %{registry: reg} do
      assert {:error, :unknown_tool} = ToolRegistryServer.unregister_tool(reg, :ghost)
    end

    test "can re-register after unregistering", %{registry: reg} do
      register_simple(reg, :re_reg)
      assert :ok = ToolRegistryServer.unregister_tool(reg, :re_reg)
      assert :ok = ToolRegistryServer.register_tool(reg, :re_reg, %{
               description: "Re-registered",
               parameters: %{type: "object", properties: %{}, required: []},
               execute: fn _ -> {:ok, :again} end
             })
      assert {:ok, :again} = ToolRegistryServer.execute_tool(reg, :re_reg, %{})
    end
  end

  describe "clear/1" do
    test "removes all tools", %{registry: reg} do
      register_simple(reg, :a)
      register_simple(reg, :b)
      register_simple(reg, :c)
      assert length(ToolRegistryServer.list_tools(reg)) == 3
      assert :ok = ToolRegistryServer.clear(reg)
      assert ToolRegistryServer.list_tools(reg) == []
    end

    test "registry is functional after clear", %{registry: reg} do
      register_simple(reg, :old)
      assert :ok = ToolRegistryServer.clear(reg)
      register_simple(reg, :new)
      assert {:ok, :ok} = ToolRegistryServer.execute_tool(reg, :new, %{})
    end
  end

  describe "task_supervisor_name/1" do
    test "returns derived atom name" do
      result = ToolRegistryServer.task_supervisor_name(:my_reg)
      assert result == :"Elixir.my_reg.TaskSupervisor"
    end
  end

  # --- Helpers ---

  defp register_simple(reg, name) do
    ToolRegistryServer.register_tool(reg, name, %{
      description: "Simple tool #{name}",
      parameters: %{type: "object", properties: %{}, required: []},
      execute: fn _ -> {:ok, :ok} end
    })
  end
end
