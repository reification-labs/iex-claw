defmodule IExClaw.ToolRegistryServerTest do
  use ExUnit.Case, async: true

  alias IExClaw.ToolRegistryServer

  setup do
    name = :"test_registry_#{System.unique_integer([:positive])}"
    {:ok, _pid} = ToolRegistryServer.start_link(name: name)
    {:ok, registry: name}
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
    test "handler receives :tool_registered events", %{registry: reg} do
      # Use an Agent as counter since telemetry fires in the GenServer process
      {:ok, counter} = Agent.start_link(fn -> [] end)
      handler = "test-reg-#{System.unique_integer()}"

      :telemetry.attach(
        handler,
        [:tool_registry, :tool_registered],
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

    test "handler receives :tool_executed events on success", %{registry: reg} do
      {:ok, counter} = Agent.start_link(fn -> [] end)
      handler = "test-exec-#{System.unique_integer()}"

      :telemetry.attach(
        handler,
        [:tool_registry, :tool_executed],
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
      assert metadata.status == :ok

      :telemetry.detach(handler)
      Agent.stop(counter)
    end

    test "handler receives :tool_executed with error status on crash", %{registry: reg} do
      {:ok, counter} = Agent.start_link(fn -> [] end)
      handler = "test-crash-#{System.unique_integer()}"

      :telemetry.attach(
        handler,
        [:tool_registry, :tool_executed],
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
      assert metadata.status == :execution_failed

      :telemetry.detach(handler)
      Agent.stop(counter)
    end
  end

  describe "child_spec" do
    test "returns valid child spec with worker type" do
      spec = ToolRegistryServer.child_spec(name: :test_spec)
      assert spec.id == :test_spec
      assert spec.type == :worker
    end

    test "default name is the module" do
      spec = ToolRegistryServer.child_spec([])
      assert spec.id == ToolRegistryServer
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
