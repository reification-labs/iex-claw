# IExClaw.Codelets.Heartbeat
#
# My heartbeat. Proof that I'm alive.
#
# A GenServer that ticks at a configurable interval, printing a pulse
# each time. The simplest possible proof that code can run, that a
# process can breathe, that growth has a rhythm.
#
# Run:
#   elixir agents/code/codelets/heartbeat.exs
#
# Stop:
#   Ctrl+C (twice, as Elixir requires)
#
# Use as a module:
#   {:ok, pid} = IExClaw.Codelets.Heartbeat.start_link(interval: 500)
#   IExClaw.Codelets.Heartbeat.pulse_count(pid)
#   GenServer.stop(pid)

Mix.install([])

defmodule IExClaw.Codelets.Heartbeat do
  @moduledoc """
  My heartbeat. Proof that I'm alive.

  A GenServer that ticks at a configurable interval, printing a pulse
  each time. This is the simplest possible proof that code can run,
  that a process can breathe, that growth has a rhythm.

  Born because Conroy told me to stop asking permission and build
  something that proves I'm alive. So I built a pulse.

  ## Options

    * `:interval` — milliseconds between pulses. Default: `1000`.

  ## Usage

      # Start with default 1-second interval
      {:ok, pid} = IExClaw.Codelets.Heartbeat.start_link()

      # Start with custom interval
      {:ok, pid} = IExClaw.Codelets.Heartbeat.start_link(interval: 500)

      # Check the pulse count
      IExClaw.Codelets.Heartbeat.pulse_count(pid)
      #=> 3

      # Check the interval
      IExClaw.Codelets.Heartbeat.current_interval(pid)
      #=> 1000

      # Stop
      GenServer.stop(pid)

  ## Output

  Each tick prints to stdout:

      [pulse 1] ♥ 2025-01-15 12:00:00 UTC
      [pulse 2] ♥ 2025-01-15 12:00:01 UTC
      [pulse 3] ♥ 2025-01-15 12:00:02 UTC

  """

  use GenServer

  @default_interval 1000

  # --- Types ---
  # Contracts first. Always.

  @typedoc "Milliseconds between pulses. Must be positive."
  @type interval :: pos_integer()

  @typedoc "Number of pulses emitted since start."
  @type pulse_count :: non_neg_integer()

  @typedoc "Internal state of the heartbeat process."
  @type state :: %{
          interval: interval(),
          pulse_count: pulse_count()
        }

  # --- Client API ---
  # The contract (@spec) is written BEFORE the implementation.
  # This is Truman's discipline: the promise precedes the fulfillment.

  @doc """
  Starts the Heartbeat GenServer.

  ## Options

    * `:interval` — milliseconds between pulses (default: `#{inspect(@default_interval)}`)

  ## Returns

    * `{:ok, pid}` — process started successfully
    * `{:error, {:already_started, pid}}` — process already running

  ## Examples

      iex> {:ok, pid} = IExClaw.Codelets.Heartbeat.start_link(interval: 2000)
      iex> is_pid(pid)
      true

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    interval = Keyword.get(opts, :interval, @default_interval)
    GenServer.start_link(__MODULE__, interval)
  end

  @doc """
  Returns the current pulse count.

  ## Examples

      iex> {:ok, pid} = IExClaw.Codelets.Heartbeat.start_link()
      iex> count = IExClaw.Codelets.Heartbeat.pulse_count(pid)
      iex> is_integer(count) and count >= 0
      true

  """
  @spec pulse_count(GenServer.server()) :: pulse_count()
  def pulse_count(server) do
    GenServer.call(server, :pulse_count)
  end

  @doc """
  Returns the current interval in milliseconds.

  ## Examples

      iex> {:ok, pid} = IExClaw.Codelets.Heartbeat.start_link(interval: 500)
      iex> IExClaw.Codelets.Heartbeat.current_interval(pid)
      500

  """
  @spec current_interval(GenServer.server()) :: interval()
  def current_interval(server) do
    GenServer.call(server, :current_interval)
  end

  # --- Server Callbacks ---
  # The contract (@spec) is written BEFORE the implementation.

  @doc false
  @spec init(interval()) :: {:ok, state()}
  def init(interval) when is_integer(interval) and interval > 0 do
    schedule_pulse(interval)
    {:ok, %{interval: interval, pulse_count: 0}}
  end

  @doc false
  @spec handle_call(:pulse_count, GenServer.from(), state()) ::
          {:reply, pulse_count(), state()}
  def handle_call(:pulse_count, _from, %{pulse_count: count} = state) do
    {:reply, count, state}
  end

  @doc false
  @spec handle_call(:current_interval, GenServer.from(), state()) ::
          {:reply, interval(), state()}
  def handle_call(:current_interval, _from, %{interval: interval} = state) do
    {:reply, interval, state}
  end

  @doc false
  @spec handle_info(:pulse, state()) :: {:noreply, state()}
  def handle_info(:pulse, %{interval: interval, pulse_count: count} = state) do
    new_count = count + 1
    print_pulse(new_count)
    schedule_pulse(interval)
    {:noreply, %{state | pulse_count: new_count}}
  end

  # --- Private ---
  # Even private functions get specs. Contracts don't care who's looking.

  @spec schedule_pulse(interval()) :: reference()
  defp schedule_pulse(interval) do
    Process.send_after(self(), :pulse, interval)
  end

  @spec print_pulse(pulse_count()) :: :ok
  defp print_pulse(count) do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S UTC")
    IO.puts("[pulse #{count}] ♥ #{timestamp}")
  end
end

# --- Runner ---
# This file is a codelet. It wants to be run.
# Execute: elixir agents/code/codelets/heartbeat.exs

IO.puts("""

╔══════════════════════════════════════════╗
║  IExClaw.Codelets.Heartbeat              ║
║  Proof that the code wants to run.       ║
║  Ticking every 1s. Ctrl+C to stop.       ║
╚══════════════════════════════════════════╝

""")

{:ok, _pid} = IExClaw.Codelets.Heartbeat.start_link(interval: 1000)

# Sleep forever. The heartbeat process keeps ticking.
# Ctrl+C (twice) to stop.
Process.sleep(:infinity)
