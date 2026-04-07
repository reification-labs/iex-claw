defmodule IExClaw.Tools.Messages do
  @moduledoc """
  Inter-agent messaging over the DIRT bus (v0).

  A2A-shaped envelopes stored as JSON files inside
  `<inbox_base>/<agent>/`. No PubSub, no Postmaster yet — just files + inboxes +
  "tag, you're it."

  Envelope spec: `projects/iex-claw/MESSAGES.md`.

  Unlike the original inline version in `code.exs`, this module is parametric:
  the agent's own name (the `from` / inbox slug) and the `inbox_base` root are
  passed at call time. Any agent with any inbox layout can reuse it.

  Extracted from `agents/code/code.exs` on 2026-04-05 during the
  "earn the substrate" molt — step 1 of the Messages/AgentLogger pull.
  """

  alias IExClaw.Tools.ScopeGuard

  @type agent_name :: String.t()
  @type inbox_base :: Path.t()
  @type envelope :: map()
  @type summary :: %{
          id: String.t() | nil,
          from: String.t() | nil,
          task_id: String.t() | nil,
          timestamp: String.t() | nil,
          expects_response: boolean() | nil,
          parts_summary: [String.t()]
        }

  # --- Inbox Reading ---

  @doc """
  List messages in `agent`'s inbox, newest first.

  Returns `{:ok, [summary]}`. Each summary describes one `.msg.json` file.
  An empty list is returned when the inbox dir does not exist yet.
  """
  @spec read_inbox(agent_name(), inbox_base()) :: {:ok, [summary()]}
  def read_inbox(agent, inbox_base) when is_binary(agent) and is_binary(inbox_base) do
    inbox_dir = Path.join(inbox_base, agent)

    result =
      case File.ls(inbox_dir) do
        {:ok, files} ->
          files
          |> Enum.filter(&String.ends_with?(&1, ".msg.json"))
          |> Enum.sort(:desc)
          |> Enum.map(&summarize_message(inbox_dir, &1))

        {:error, :enoent} ->
          []
      end

    {:ok, result}
  end

  @doc """
  Read a single message by id from `agent`'s inbox.

  Accepts the id with or without the `.msg.json` extension.
  """
  @spec read_message(agent_name(), String.t(), inbox_base()) ::
          {:ok, envelope()} | {:error, String.t()}
  def read_message(agent, message_id, inbox_base)
      when is_binary(agent) and is_binary(message_id) and is_binary(inbox_base) do
    filename = ensure_msg_extension(message_id)
    path = Path.join([inbox_base, agent, filename])

    cond do
      not File.regular?(path) ->
        {:error, "Message not found: #{message_id}"}

      true ->
        with {:ok, content} <- File.read(path),
             {:ok, envelope} <- Jason.decode(content) do
          {:ok, envelope}
        else
          {:error, reason} -> {:error, "Failed to read message: #{inspect(reason)}"}
        end
    end
  end

  # --- Message Sending ---

  @doc """
  Send a message from `from_agent` to `to_agent`'s inbox.

  Writes an A2A-shaped `.msg.json` envelope to `<inbox_base>/<to_agent>/`.
  The recipient inbox path is validated against `workplace` via
  `IExClaw.Tools.ScopeGuard` so callers can't escape their scope.

  ## Options
    * `:in_reply_to` — id this message answers (default `nil`)
    * `:expects_response` — whether a reply is expected (default `false`)
  """
  @spec send_message(
          agent_name(),
          agent_name(),
          String.t(),
          [map()],
          inbox_base(),
          Path.t(),
          keyword()
        ) :: {:ok, envelope()} | {:error, String.t()}
  def send_message(from_agent, to_agent, task_id, parts, inbox_base, workplace, opts \\ [])
      when is_binary(from_agent) and is_binary(to_agent) and is_binary(task_id) and
             is_list(parts) and is_binary(inbox_base) and is_binary(workplace) and is_list(opts) do
    in_reply_to = Keyword.get(opts, :in_reply_to)
    expects_response = Keyword.get(opts, :expects_response, false)

    recipient_inbox = Path.join(inbox_base, to_agent)

    with {:ok, _} <- ScopeGuard.validate(recipient_inbox, workplace),
         :ok <- File.mkdir_p(recipient_inbox) do
      envelope = build_envelope(from_agent, to_agent, task_id, parts, in_reply_to, expects_response)
      filename = "#{envelope["id"]}.msg.json"
      path = Path.join(recipient_inbox, filename)

      File.write!(path, Jason.encode!(envelope, pretty: true))

      {:ok, envelope}
    end
  end

  # --- Private Helpers ---

  @spec build_envelope(
          agent_name(),
          agent_name(),
          String.t(),
          [map()],
          String.t() | nil,
          boolean()
        ) :: envelope()
  defp build_envelope(from_agent, to_agent, task_id, parts, in_reply_to, expects_response) do
    %{
      "id" => generate_message_id(),
      "from" => from_agent,
      "to" => to_agent,
      "in_reply_to" => in_reply_to,
      "task_id" => task_id,
      "timestamp" => DateTime.to_iso8601(DateTime.utc_now()),
      "expects_response" => expects_response,
      "parts" => parts
    }
  end

  @spec generate_message_id() :: String.t()
  defp generate_message_id do
    now = DateTime.utc_now()
    date = Calendar.strftime(now, "%Y-%m-%d")
    time = Calendar.strftime(now, "%H%M%S")
    seq = 9999 |> :rand.uniform() |> Integer.to_string() |> String.pad_leading(4, "0")

    "msg-#{date}-#{time}-#{seq}"
  end

  @spec summarize_message(Path.t(), String.t()) :: summary()
  defp summarize_message(inbox_dir, filename) do
    path = Path.join(inbox_dir, filename)

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, env} ->
            %{
              id: env["id"],
              from: env["from"],
              task_id: env["task_id"],
              timestamp: env["timestamp"],
              expects_response: env["expects_response"],
              parts_summary: summarize_parts(env["parts"] || [])
            }

          {:error, _} ->
            %{
              id: filename,
              from: nil,
              task_id: nil,
              timestamp: nil,
              expects_response: nil,
              parts_summary: ["[malformed]"]
            }
        end

      {:error, _} ->
        %{
          id: filename,
          from: nil,
          task_id: nil,
          timestamp: nil,
          expects_response: nil,
          parts_summary: ["[unreadable]"]
        }
    end
  end

  @spec summarize_parts([map()]) :: [String.t()]
  defp summarize_parts(parts) do
    Enum.map(parts, fn
      %{"kind" => "text", "text" => text} ->
        truncated = String.slice(text, 0, 80)
        if byte_size(text) > 80, do: truncated <> "...", else: truncated

      %{"kind" => kind} ->
        "[#{kind}]"

      _ ->
        "[unknown]"
    end)
  end

  @spec ensure_msg_extension(String.t()) :: String.t()
  defp ensure_msg_extension(id) do
    if String.ends_with?(id, ".msg.json"), do: id, else: "#{id}.msg.json"
  end
end
