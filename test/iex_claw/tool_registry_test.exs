defmodule IExClaw.ToolRegistryTest do
  use ExUnit.Case, async: true

  alias IExClaw.ToolRegistry

  # A stub tool module for testing
  defmodule StubTool do
    @moduledoc false
    def greet(name), do: {:ok, "Hello, #{name}!"}
    def add(a, b), do: {:ok, a + b}
  end

  @tools %{
    "greet" =>
      {StubTool, :greet, "Say hello to someone", [%{name: "name", type: "string", description: "Who to greet"}]},
    "add" =>
      {StubTool, :add, "Add two numbers",
       [
         %{name: "a", type: "integer", description: "First number"},
         %{name: "b", type: "integer", description: "Second number"}
       ]}
  }

  describe "as_openai_tools/2" do
    test "converts tools to OpenAI function-calling schema" do
      result = ToolRegistry.as_openai_tools(@tools)
      assert length(result) == 2

      greet = Enum.find(result, &(&1["function"]["name"] == "greet"))
      assert greet["type"] == "function"
      assert greet["function"]["description"] == "Say hello to someone"
      assert greet["function"]["parameters"]["properties"]["name"]["type"] == "string"
      assert greet["function"]["parameters"]["required"] == ["name"]
    end

    test "excludes optional params from required list" do
      tools_with_optional = %{
        "write" =>
          {StubTool, :greet, "Write something",
           [
             %{name: "path", type: "string", description: "File path"},
             %{name: "overwrite", type: "boolean", description: "Overwrite?"}
           ]}
      }

      [schema] = ToolRegistry.as_openai_tools(tools_with_optional, ["overwrite"])
      assert schema["function"]["parameters"]["required"] == ["path"]
    end
  end

  describe "execute/3" do
    test "dispatches to the correct module and function" do
      assert {:ok, "Hello, World!"} = ToolRegistry.execute(@tools, "greet", %{"name" => "World"})
    end

    test "passes args in param order" do
      assert {:ok, 7} = ToolRegistry.execute(@tools, "add", %{"a" => 3, "b" => 4})
    end

    test "returns error for unknown tool" do
      assert {:error, "Unknown tool: nope"} = ToolRegistry.execute(@tools, "nope", %{})
    end
  end
end
