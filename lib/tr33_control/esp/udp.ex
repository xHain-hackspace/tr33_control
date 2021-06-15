defmodule Tr33Control.ESP.UDP do
  use GenServer
  require Logger
  alias Tr33Control.Commands
  alias Tr33Control.Commands.Command
  alias Tr33Control.ESP

  @tick_interval_ms 30
  @max_queue_len 5
  @udp_registry :udp_targets
  @target_port 1337

  def start_link({target, host, process_name}) when is_atom(target) do
    GenServer.start_link(__MODULE__, {target, host}, name: process_name)
  end

  def toggle_debug() do
    current = Application.get_env(:tr33_control, :udp_debug, false)
    Application.put_env(:tr33_control, :udp_debug, not current)
  end

  def init({target, host}) do
    case host |> String.to_charlist() |> :inet.gethostbyname(:inet) do
      {:ok, {:hostent, _host, [], :inet, 4, [{192, _, _, _} = ip | _]}} ->
        "#{__MODULE__}: Resovled host #{host} for target #{inspect(target)} to #{inspect(ip)}. Sending UDP commands to port #{@target_port}"
        |> Logger.info()

        {:ok, socket} = :gen_udp.open(Enum.random(5000..65535), [:binary])

        state = %{
          socket: socket,
          last_packet: System.os_time(:millisecond),
          queue: :queue.new(),
          target: target,
          host: host,
          ip: ip,
          sequence: 1
        }

        :timer.send_interval(@tick_interval_ms, :tick)

        {:ok, _} = Registry.register(@udp_registry, ip, target)

        Commands.subscribe_commands()
        ESP.subscribe()

        {:ok, state}

      other ->
        debug_log(%{host: host}, "Could not resolve host. Not sending UDP commands. Reason: #{inspect(other)}")
        :ignore
    end
  end

  def handle_cast({:sequence, received}, %{sequence: expected} = state) do
    if expected == received do
      {:noreply, state}
    else
      Logger.info("#{__MODULE__}: Unexpected sequence, got: #{received} expected: #{expected}. Enqueue rsync")
      {:noreply, resync_queue(state)}
    end
  end

  def handle_info({:command_update, %Command{} = command}, state) do
    state = maybe_enqueue(state, command)

    {:noreply, state}
  end

  def handle_info({:command_deleted, index}, state) do
    command = Command.disabled(index)
    state = maybe_enqueue(state, command)
    {:noreply, state}
  end

  def handle_info(:time_sync, state) do
    binary = Commands.time_sync_binary()
    transmit_binary(binary, state)
    {:noreply, state}
  end

  def handle_info(:tick, %{queue: queue, target: target, sequence: sequence} = state) do
    state =
      case :queue.out(queue) do
        {:empty, _} ->
          state

        {{:value, %Command{} = command}, rest} ->
          next_sequence = rem(sequence + 1, 256)

          command
          |> Commands.command_binary(target, next_sequence)
          |> transmit_binary(state)

          %{state | queue: rest, sequence: next_sequence}
      end

    {:noreply, state}
  end

  defp maybe_enqueue(%{queue: queue} = state, %Command{} = command) do
    queue =
      if :queue.len(queue) < @max_queue_len do
        :queue.in(command, queue)
      else
        queue
        |> :queue.drop()
        |> then(&:queue.in(command, &1))
      end

    %{state | queue: queue}
  end

  defp resync_queue(state) do
    queue =
      Commands.list_commands(include_empty: true)
      |> Enum.reduce(:queue.new(), fn %Command{} = command, queue_acc -> :queue.in(command, queue_acc) end)

    %{state | queue: queue}
  end

  defp transmit_binary(binary, state = %{socket: socket, host: host}) when is_binary(binary) do
    debug_log(state, "Sending packet: #{inspect(binary)}")

    :ok = :gen_udp.send(socket, String.to_charlist(host), @target_port, binary)
  end

  def debug_log(%{host: host}, message) do
    if Application.get_env(:tr33_control, :udp_debug, false) do
      Logger.debug("#{__MODULE__} #{inspect(host)}: #{message}")
    end
  end
end
