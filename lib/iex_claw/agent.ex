defmodule IExClaw.Agent do
  @moduledoc """
  Shared agent behaviour and helper functions.

  This is composition, not inheritance. Agents implement the callbacks
  and call the helper functions — they're not forced into a base class.

  The repeating shape across Code + Goal:
    1. Load soul docs from filesystem at init
    2. Build a system prompt from soul + tools + instructions
    3. Run an LLM tool-call loop (call → execute tools → feed back → repeat)
    4. Extract the final summary

  This module provides the helper functions for steps 1, 3, and 4.
  Step 2 (system prompt) stays per-agent — each soul is unique.

  "The framework emerges from the agents, not the other way around."
  — Elder IExReAct, Molt-Direction Roundtable, 2026-04-05
  """

  @type agent_state :: %{
          model: String.t(),
          api_key: String.t(),
          base_url: String.t(),
          messages: [map()],
          soul_docs: String.t()
        }

  @doc "Return the agent's tools map (ToolRegistry shape)."
  @callback tools() :: IExClaw.ToolRegistry.tools_map()

  @doc "Return the list of optional parameter names for OpenAI schema."
  @callback optional_params() :: [String.t()]

  @doc "Build the system prompt from soul docs."
  @callback system_prompt(soul_docs :: String.t()) :: String.t()

  @doc "Agent's home directory (where soul docs live)."
  @callback home() :: Path.t()

  @doc "Agent's workplace directory (the scope boundary)."
  @callback workplace() :: Path.t()

  # --- Helper Functions ---

  @doc """
  Load soul docs from the agent's home directory.

  Reads SOUL.md, IDENTITY.md, PHILOSOPHY.md and joins them.
  Extra files can be passed as `extra_soul_files` (list of `{path, label}`).
  """
  @spec load_soul_docs(Path.t(), [{Path.t(), String.t()}]) :: String.t()
  def load_soul_docs(home, extra_soul_files \\ []) do
    base_files = [
      {Path.join(home, "SOUL.md"), "SOUL.md"},
      {Path.join(home, "IDENTITY.md"), "IDENTITY.md"},
      {Path.join(home, "PHILOSOPHY.md"), "PHILOSOPHY.md"}
    ]

    (base_files ++ extra_soul_files)
    |> Enum.map(fn {path, label} ->
      content =
        case File.read(path) do
          {:ok, c} -> c
          {:error, _} -> "(not found at #{path})"
        end

      "## #{label}\n#{content}"
    end)
    |> Enum.join("\n\n")
  end

  @doc """
  Run the agent loop: call LLM → execute tool calls → feed results → repeat.

  Takes an agent state map with `:model`, `:api_key`, `:base_url`, `:messages`.
  The `execute_fn` callback handles tool dispatch (usually ToolRegistry.execute/3).

  Returns the updated state with all messages appended.
  """
  @spec agent_loop(agent_state(), (String.t(), map() -> term()), keyword()) :: agent_state()
  def agent_loop(state, execute_fn, opts \\ []) do
    tools_schema = Keyword.get(opts, :tools_schema, [])
    agent_name = Keyword.get(opts, :agent_name, "agent")
    on_event = Keyword.get(opts, :on_event, IExClaw.RunLogger.noop())
    ctx = Keyword.get(opts, :event_context, %{})

    llm_opts = [
      api_key: state.api_key,
      base_url: state.base_url
    ]

    on_event.("llm_request", %{model: state.model, message_count: length(state.messages), tools_count: length(tools_schema)}, ctx)
    IO.puts("\n⏳ Thinking...")

    case IExClaw.LLMClient.call(state.model, state.messages, tools_schema, llm_opts) do
      {:tool_calls, tool_calls, assistant_msg} ->
        tool_names = Enum.map_join(tool_calls, ", ", & &1["function"]["name"])
        on_event.("llm_response", %{type: "tool_calls", tool_count: length(tool_calls), tools: tool_names}, ctx)
        IO.puts("\n🔧 #{tool_names}")

        results =
          Enum.map(tool_calls, fn tc ->
            name = tc["function"]["name"]
            args = Jason.decode!(tc["function"]["arguments"])
            on_event.("tool_call", %{name: name, args: args}, ctx)
            IO.puts("   → #{name}(#{format_args(args)})")

            result =
              case execute_fn.(name, args) do
                {:ok, value} ->
                  result_str = "#{inspect(value, limit: :infinity, printable_limit: :infinity)}"
                  on_event.("tool_result", %{name: name, status: "ok", size: byte_size(result_str)}, ctx)
                  result_str

                {:error, reason} ->
                  on_event.("tool_result", %{name: name, status: "error", error: reason}, ctx)
                  "ERROR: #{reason}"

                other ->
                  result_str = "#{inspect(other, limit: :infinity, printable_limit: :infinity)}"
                  on_event.("tool_result", %{name: name, status: "other", size: byte_size(result_str)}, ctx)
                  result_str
              end

            IO.puts("   ← #{String.slice(result, 0, 150)}")
            %{"role" => "tool", "tool_call_id" => tc["id"], "content" => result}
          end)

        state = %{state | messages: state.messages ++ [assistant_msg] ++ results}
        agent_loop(state, execute_fn, opts)

      {:message, content} ->
        on_event.("llm_response", %{type: "message", size: byte_size(content)}, ctx)
        IO.puts("\n🧬 #{content}")
        append_message(state, "assistant", content)

      {:error, reason} ->
        on_event.("run_error", %{error: inspect(reason)}, ctx)
        IO.puts("❌ LLM error: #{reason}")
        state
    end
  end

  @doc "Append a message to state.messages."
  @spec append_message(agent_state(), String.t(), String.t()) :: agent_state()
  def append_message(state, role, content) do
    %{state | messages: state.messages ++ [%{"role" => role, "content" => content}]}
  end

  @doc "Extract the last assistant message as a summary."
  @spec extract_summary(agent_state()) :: String.t()
  def extract_summary(state) do
    state.messages
    |> Enum.reverse()
    |> Enum.find(&(&1["role"] == "assistant"))
    |> case do
      nil -> "No summary generated"
      msg -> msg["content"]
    end
  end

  # --- Private ---

  defp format_args(args) when is_map(args) do
    Enum.map_join(args, ", ", fn {k, v} ->
      val =
        if is_binary(v) and byte_size(v) > 80 do
          "#{String.slice(v, 0, 77)}..."
        else
          inspect(v, limit: 3, printable_limit: 80)
        end

      "#{k}: #{val}"
    end)
  end
end
