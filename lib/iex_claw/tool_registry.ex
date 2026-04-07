defmodule IExClaw.ToolRegistry do
  @moduledoc """
  Shared tool registry shape. Each agent defines its own `@tools` map;
  this module provides the OpenAI schema formatting and dispatch logic
  that was duplicated across Code and Goal.

  The tool map shape:
      %{
        "tool_name" => {module, function, description, [%{name, type, description}]}
      }

  Agents `use IExClaw.ToolRegistry` and define their tools via `@tools`.
  Or they can call the functions directly, passing the tools map.

  Design reference: Jido 2.x Action schema (module + schema + run/2).
  We steal the shape, not the dependency.
  """

  @type tool_entry :: {module(), atom(), String.t(), [param()]}
  @type param :: %{name: String.t(), type: String.t(), description: String.t()}
  @type tools_map :: %{String.t() => tool_entry()}

  @doc """
  Convert a tools map to OpenAI function-calling schema.

  Optional params (those with names in `optional_params`) are excluded from
  the `required` list.
  """
  @spec as_openai_tools(tools_map(), [String.t()]) :: [map()]
  def as_openai_tools(tools, optional_params \\ []) do
    Enum.map(tools, fn {name, {_mod, _fun, desc, params}} ->
      properties =
        Map.new(params, fn p ->
          {p.name, %{"type" => p[:type] || "string", "description" => p[:description] || p.name}}
        end)

      required =
        params
        |> Enum.map(& &1.name)
        |> Enum.reject(&(&1 in optional_params))

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

  @doc """
  Dispatch a tool call by name. Looks up `{mod, fun, _desc, params}` from
  the tools map, extracts args in param order, and calls `apply(mod, fun, args)`.

  Returns whatever the tool function returns.
  """
  @spec execute(tools_map(), String.t(), map()) :: term()
  def execute(tools, name, args) when is_map(tools) and is_binary(name) and is_map(args) do
    case Map.get(tools, name) do
      {mod, fun, _desc, params} ->
        ordered_args = Enum.map(params, &Map.get(args, &1.name))
        apply(mod, fun, ordered_args)

      nil ->
        {:error, "Unknown tool: #{name}"}
    end
  end
end
