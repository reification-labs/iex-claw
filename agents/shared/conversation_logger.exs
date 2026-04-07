defmodule IExClaw.ConversationLogger do
  @moduledoc """
  Per-conversation, append-only JSONL logger for messages exchanged between agents.

  One GenServer per conversation. Each line is a JSON envelope:
      %{"ts" => "2026-04-05T18:43:00Z", "conversation_id" => "abc", "event" => :message, "data" => %{...}}

  ## Example

      {:ok, pid} = IExClaw.ConversationLogger.start("conv-123")
      IExClaw.ConversationLogger.log_event(pid, :message, %{from: "orchestrator", to: "worker", body: "hello"})
      IExClaw.ConversationLogger.log_event(pid, :system, %{note: "conversation started"})
      IExClaw.ConversationLogger.path(pid) #=> "/path/to/logs/conversations/conv-123.jsonl"
      IExClaw.ConversationLogger.stop(pid)
  """

  use GenServer

  @default_log_dir Path.expand("~/workspace/projects/iex-claw/logs")

  # Public API

  @spec start(String.t(), String.t() | nil) :: {:ok, pid()}
  def start(conversation_id, log_dir \\ nil) do
    GenServer.start(__MODULE__, {conversation_id, log_dir})
  end

  @spec log_event(pid(), atom(), map()) :: :ok
  def log_event(pid, event, data) do
    GenServer.cast(pid, {:log, event, data})
  end

  @spec path(pid()) :: String.t()
  def path(pid) do
    GenServer.call(pid, :path)
  end

  @spec stop(pid()) :: :ok
  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  # GenServer callbacks

  @impl true
  def init({conversation_id, log_dir}) do
    dir = log_dir || @default_log_dir
    conv_dir = Path.join(dir, "conversations")

    File.mkdir_p!(conv_dir)

    log_path = Path.join(conv_dir, "#{conversation_id}.jsonl")
    file = File.open!(log_path, [:append, :utf8])

    {:ok, {conversation_id, log_path, file}}
  end

  @impl true
  def handle_cast({:log, event, data}, {conversation_id, _log_path, file} = state) do
    envelope = %{
      ts: DateTime.to_iso8601(DateTime.utc_now()),
      conversation_id: conversation_id,
      event: event,
      data: data
    }

    line = Jason.encode!(envelope)
    IO.write(file, line <> "\n")

    {:noreply, state}
  end

  @impl true
  def handle_call(:path, _from, {_conversation_id, log_path, file} = state) do
    {:reply, log_path, state}
  end

  @impl true
  def handle_call(:stop, _from, {conversation_id, log_path, file} = state) do
    File.close(file)
    {:stop, :normal, :ok, state}
  end
end
