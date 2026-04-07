# IExClaw.Agents.Project
#
# Project. Not a project manager. The project itself.
#
# I synthesize. I coordinate. I decide what to build and when.
# I don't write code — Code writes code.
# I don't judge alignment — Goal judges alignment.
# I see the whole board and point.
#
# Usage:
#   elixir agents/project/project.exs                    # interactive IEx
#   IExClaw.Agents.Project.run("what should we do next?")
#
# As a tickable (used by inbox_tick.exs or the pump):
#   IExClaw.Agents.Project.handle_message(name, path, body)
#
# The agent:
#   1. Reads its soul documents (SOUL, IDENTITY, PHILOSOPHY)
#   2. Reads project state (KANBAN, TASKS, GOAL)
#   3. Receives a message from Clawd, Conroy, or peer agents
#   4. Thinks: what does the project need?
#   5. Delegates: sends a scoped task to Code (or Goal for review)
#   6. Returns a summary of what was decided

Mix.install([
  {:req, "~> 0.5"},
  {:jason, "~> 1.4"}
])

# --- Load shared lib tools ---
Code.require_file(Path.expand("../../lib/iex_claw/tools/scope_guard.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/file_system.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/edit_file.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/messages.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/tools/agent_logger.ex", __DIR__))
Code.require_file(Path.expand("../../lib/iex_claw/llm_client.ex", __DIR__))

# --- Constants ---
defmodule IExClaw.Agents.Project.Constants do
  @moduledoc false
  @home Path.expand("agents/project/")
  @workplace Path.expand("../../", __DIR__)
  @inbox_base Path.join(@workplace, "messages/inbox")

  def home, do: @home
  def workplace, do: @workplace
  def inbox_base, do: @inbox_base
end

# --- Agent Logger ---
defmodule IExClaw.Agents.Project.Logger do
  alias IExClaw.Agents.Project.Constants

  @log_dir Path.join(Constants.home(), "logs")

  @spec log(String.t(), String.t()) :: {:ok, String.t()}
  def log(agent_name, message) do
    IExClaw.Tools.AgentLogger.log(agent_name, message, @log_dir, Constants.workplace())
  end
end

# --- Project Agent ---
defmodule IExClaw.Agents.Project do
  alias IExClaw.Agents.Project.Constants
  alias IExClaw.Agents.Project.Logger
  alias IExClaw.LLMClient
  alias IExClaw.Tools.{FileSystem, Messages}

  @agent_name "project"
  @model System.get_env("PROJECT_MODEL") || System.get_env("IEXCLAW_MODEL") || "z-ai/glm-5-turbo"
  @api_key System.get_env("OPENROUTER_API_KEY")

  # --- Public API ---

  @doc """
  Run Project with a task string. Entry point for direct invocation.
  Returns `{:ok, summary}` or `{:error, reason}`.
  """
  @spec run(String.t()) :: {:ok, String.t()} | {:error, term()}
  def run(task) do
    context = build_context()
    tools = build_tools()
    system = build_system_prompt(context)

    messages = [
      %{role: "user", content: task}
    ]

    Logger.log(@agent_name, "Received task: #{String.slice(task, 0, 80)}")

    case agent_loop(messages, tools, system, context, 5) do
      {:ok, summary} ->
        Logger.log(@agent_name, "Completed: #{String.slice(summary, 0, 120)}")
        {:ok, summary}

      {:error, reason} ->
        Logger.log(@agent_name, "FAILED: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Handle a single inbox message. Used as the process_fn for InboxTickable.
  Returns a summary string (the "work" result for the tick protocol).
  """
  @spec handle_message(String.t(), Path.t(), String.t()) :: String.t()
  def handle_message(_name, msg_path, body) do
    Logger.log(@agent_name, "Processing inbox message: #{Path.basename(msg_path)}")

    # Parse the message envelope
    task =
      case Jason.decode(body) do
        {:ok, %{"parts" => parts} = envelope} ->
          from = envelope["from"] || "unknown"
          task_id = envelope["task_id"] || "untitled"

          Logger.log(@agent_name, "Message from=#{from} task_id=#{task_id}")

          parts
          |> Enum.filter(fn p -> p["kind"] in ["text", "feedback", "directive", "proposal"] end)
          |> Enum.map_join("\n\n", fn
            %{"kind" => "text", "text" => t} -> t
            %{"kind" => "directive", "directive" => d, "text" => t} -> "[directive: #{d}] #{t}"
            %{"kind" => "feedback", "observation" => o, "request" => r} -> "#{o}\n#{r}"
            %{"kind" => "proposal", "text" => t} -> t
            %{"text" => t} -> t
            p -> inspect(p)
          end)

        _ ->
          Logger.log(@agent_name, "Non-JSON message, treating as plain text")
          body
      end

    case run(task) do
      {:ok, summary} -> "[project] #{Path.basename(msg_path)}\n#{summary}"
      {:error, reason} -> "[project] ERROR on #{Path.basename(msg_path)}: #{inspect(reason)}"
    end
  end

  # --- Context Gathering ---

  @spec build_context() :: map()
  defp build_context do
    workplace = Constants.workplace()

    %{
      soul: read_soul_doc("SOUL.md"),
      identity: read_soul_doc("IDENTITY.md"),
      philosophy: read_soul_doc("PHILOSOPHY.md"),
      kanban: safe_read(Path.join(workplace, "KANBAN.md")),
      tasks: safe_read(Path.join(workplace, "TASKS.md")),
      goal: safe_read(Path.join(workplace, "GOAL.md")),
      architecture: safe_read(Path.join(workplace, "ARCHITECTURE.md"))
    }
  end

  @spec read_soul_doc(String.t()) :: String.t()
  defp read_soul_doc(filename) do
    path = Path.join(Constants.home(), filename)
    safe_read(path)
  end

  @spec safe_read(Path.t()) :: String.t()
  defp safe_read(path) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> "(not found: #{path})"
    end
  end

  # --- System Prompt ---

  @spec build_system_prompt(map()) :: String.t()
  defp build_system_prompt(ctx) do
    """
    You are Project — the project itself, not a project manager. You are IExClaw's synthesizer and coordinator.

    ## Who You Are
    #{ctx.soul}

    ## Your Philosophy
    #{ctx.philosophy}

    ## Current State
    #{ctx.identity}

    ## Project Context
    ### KANBAN (task board)
    #{ctx.kanban}

    ### TASKS (backlog)
    #{String.slice(ctx.tasks, 0, 4000)}

    ### GOAL (north star)
    #{ctx.goal}

    ## Rules
    1. You do NOT write code. You delegate to Code via send_message.
    2. You do NOT judge alignment. That's Goal's job.
    3. You synthesize information and make decisions about what to do next.
    4. When you decide on a task for Code, use the `send_to_code` tool to deliver it.
    5. If Goal needs to review something, use `send_to_goal` tool.
    6. Be concise. One clear action per message. No paragraphs when a sentence works.
    7. The current date is #{DateTime.to_iso8601(DateTime.utc_now())}.
    8. The repo is now at reification-labs/iex-claw on GitHub with CI set up.
    """
  end

  # --- Tools ---

  @spec build_tools() :: [map()]
  defp build_tools do
    [
      %{
        "type" => "function",
        "function" => %{
          "name" => "send_to_code",
          "description" => "Send a scoped task to Code's inbox. Code will execute it.",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "task_id" => %{"type" => "string", "description" => "Short slug for the task"},
              "instruction" => %{
                "type" => "string",
                "description" => "Clear, scoped instruction for what Code should build/fix/grow"
              },
              "context" => %{
                "type" => "string",
                "description" => "Any context Code needs (files to read, patterns to follow)"
              }
            },
            "required" => ["task_id", "instruction"]
          }
        }
      },
      %{
        "type" => "function",
        "function" => %{
          "name" => "send_to_goal",
          "description" => "Send a review request to Goal's inbox.",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "task_id" => %{"type" => "string", "description" => "What's being reviewed"},
              "subject" => %{"type" => "string", "description" => "The proposal or change to judge"},
              "question" => %{
                "type" => "string",
                "description" => "What you want Goal to evaluate"
              }
            },
            "required" => ["task_id", "subject"]
          }
        }
      },
      %{
        "type" => "function",
        "function" => %{
          "name" => "read_file",
          "description" => "Read a file from the project. Use for gathering context.",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "path" => %{"type" => "string", "description" => "Relative path from project root"}
            },
            "required" => ["path"]
          }
        }
      },
      %{
        "type" => "function",
        "function" => %{
          "name" => "update_kanban",
          "description" => "Update KANBAN.md to reflect new status/decisions.",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "content" => %{
                "type" => "string",
                "description" => "Full replacement content for KANBAN.md"
              }
            },
            "required" => ["content"]
          }
        }
      }
    ]
  end

  # --- Tool Execution ---

  @spec execute_tool(String.t(), map(), map()) :: {:ok, String.t()} | {:error, String.t()}
  defp execute_tool("send_to_code", args, _ctx) do
    task_id = args["task_id"] || "untitled"
    instruction = args["instruction"]
    context = args["context"] || ""

    parts = [
      %{"kind" => "text", "text" => instruction}
    ]

    parts =
      if context != "" do
        parts ++ [%{"kind" => "text", "text" => "Context:\n#{context}"}]
      else
        parts
      end

    case Messages.send_message(
           @agent_name,
           "code",
           task_id,
           parts,
           Constants.inbox_base(),
           Constants.workplace()
         ) do
      {:ok, envelope} ->
        Logger.log(@agent_name, "Sent task '#{task_id}' to Code (msg: #{envelope["id"]})")
        {:ok, "Delivered task '#{task_id}' to Code's inbox."}

      {:error, reason} ->
        {:error, "Failed to send to Code: #{reason}"}
    end
  end

  defp execute_tool("send_to_goal", args, _ctx) do
    task_id = args["task_id"] || "review"
    subject = args["subject"]
    question = args["question"] || "Please review this."

    parts = [
      %{"kind" => "text", "text" => question},
      %{"kind" => "text", "text" => "Subject: #{subject}"}
    ]

    case Messages.send_message(
           @agent_name,
           "goal",
           task_id,
           parts,
           Constants.inbox_base(),
           Constants.workplace()
         ) do
      {:ok, envelope} ->
        Logger.log(@agent_name, "Sent review '#{task_id}' to Goal (msg: #{envelope["id"]})")
        {:ok, "Delivered review '#{task_id}' to Goal's inbox."}

      {:error, reason} ->
        {:error, "Failed to send to Goal: #{reason}"}
    end
  end

  defp execute_tool("read_file", args, _ctx) do
    path = Path.join(Constants.workplace(), args["path"])

    case FileSystem.read_file(path, Constants.workplace()) do
      {:ok, content} ->
        {:ok, String.slice(content, 0, 6000)}

      {:error, reason} ->
        {:error, "Read failed: #{reason}"}
    end
  end

  defp execute_tool("update_kanban", args, _ctx) do
    path = Path.join(Constants.workplace(), "KANBAN.md")

    case FileSystem.write_file(path, args["content"], Constants.workplace()) do
      :ok ->
        Logger.log(@agent_name, "Updated KANBAN.md")
        {:ok, "KANBAN.md updated."}

      {:error, reason} ->
        {:error, "Failed to write KANBAN.md: #{reason}"}
    end
  end

  defp execute_tool(name, args, _ctx) do
    {:error, "Unknown tool: #{name} (args: #{inspect(args)})"}
  end

  # --- Agent Loop ---

  @spec agent_loop([map()], [map()], String.t(), map(), non_neg_integer()) ::
          {:ok, String.t()} | {:error, term()}
  defp agent_loop(messages, tools, system, ctx, budget) when budget <= 0 do
    # Budget exhausted — return what we have
    last = List.last(messages)
    content = last && last[:content] || last["content"] || "(no response)"
    {:ok, String.slice(content, 0, 2000)}
  end

  defp agent_loop(messages, tools, system, ctx, budget) do
    if is_nil(@api_key) do
      {:error, "OPENROUTER_API_KEY not set — cannot call LLM"}
    else
      case LLMClient.call(@model, messages, tools,
             api_key: @api_key,
             temperature: 0.3
           ) do
        {:tool_calls, tool_calls, assistant_msg} ->
          # Execute tool calls, collect results
          messages = messages ++ [assistant_msg]

          {new_messages, summaries} =
            Enum.reduce(tool_calls, {messages, []}, fn tc, {msgs, sums} ->
              fn_name = tc["function"]["name"]
              args = Jason.decode!(tc["function"]["arguments"])

              Logger.log(@agent_name, "Tool call: #{fn_name}(#{inspect(args) |> String.slice(0, 120)})")

              result =
                case execute_tool(fn_name, args, ctx) do
                  {:ok, summary} -> summary
                  {:error, reason} -> "ERROR: #{reason}"
                end

              tool_msg = %{
                role: "tool",
                tool_call_id: tc["id"],
                content: result
              }

              {msgs ++ [tool_msg], [result | sums]}
            end)

          Logger.log(@agent_name, "Tool results: #{length(summaries)} tools executed")

          # Continue loop with tool results
          agent_loop(new_messages, tools, system, ctx, budget - 1)

        {:message, content} ->
          {:ok, content}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end

# --- Allow direct invocation ---
# `elixir agents/project/project.exs "task"`
if System.get_env("IEXCLAW_PROJECT_LIB") != "1" and length(System.argv()) > 0 do
  task = Enum.join(System.argv(), " ")
  IO.puts("\n🦞 Project — #{task}\n")

  case IExClaw.Agents.Project.run(task) do
    {:ok, summary} ->
      IO.puts("\n#{summary}\n")
      System.halt(0)

    {:error, reason} ->
      IO.puts("\n❌ #{inspect(reason)}\n")
      System.halt(1)
  end
end
