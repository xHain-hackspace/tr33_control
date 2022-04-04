defmodule Tr33Control.ESP.UDP do
  use GenServer
  require Logger
  alias Tr33Control.{Commands, ESP, Joystick}
  alias Tr33Control.Commands.Command
  alias Tr33Control.Commands.Schemas.TargetMetrics

  defstruct [:socket, :queue, :target, :host, :ip, :sequence, :last_sequence, :connection, :fps, :wifi_strength]

  @tick_interval_ms 30
  @max_queue_len 5
  @udp_registry :udp_targets
  @target_port 1337
  @pubsub_topic "udp_clients"
  @sequence_timeout 21_000

  def subscribe(), do: Phoenix.PubSub.subscribe(Tr33Control.PubSub, @pubsub_topic)

  def notify_subscribers(%__MODULE__{} = state) do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @pubsub_topic, {:target_update, state})
    state
  end

  def start_link({target, host, process_name}) when is_atom(target) do
    GenServer.start_link(__MODULE__, {target, host}, name: process_name)
  end

  def toggle_debug() do
    current = Application.get_env(:tr33_control, :udp_debug, false)
    Application.put_env(:tr33_control, :udp_debug, not current)
  end

  def init({target, host}) do
    state = %__MODULE__{
      last_sequence: System.os_time(:millisecond),
      queue: :queue.new(),
      target: target,
      host: host,
      sequence: 1
    }

    case host |> String.to_charlist() |> :inet.gethostbyname(:inet) do
      {:ok, {:hostent, _host, [], :inet, 4, [{_, _, _, _} = ip | _]}} ->
        {:ok, socket} = :gen_udp.open(Enum.random(5000..65535), [:binary])

        state =
          %__MODULE__{state | socket: socket, ip: ip}
          |> set_connection_state(:started)

        info_log(
          state,
          "Resovled host #{host} for target #{inspect(target)} to #{inspect(ip)}. Sending UDP commands to port #{@target_port}"
        )

        :timer.send_interval(@tick_interval_ms, :tick)

        {:ok, _} = Registry.register(@udp_registry, ip, target)

        ESP.subscribe()
        Commands.subscribe_commands()
        Joystick.subscribe()

        {:ok, state}

      other ->
        set_connection_state(state, :nx_domain)
        debug_log(state, "Could not resolve host. Not sending UDP commands. Reason: #{inspect(other)}")

        :ignore
    end
  end

  def handle_info({:metrics, ip, seq, metrics}, %__MODULE__{sequence: seq, ip: ip} = state) do
    state =
      state
      |> set_connection_state(:ok)
      |> update_metrics(metrics)

    debug_log(state, "Expected sequence: #{seq}, doing nothing")

    {:noreply, %__MODULE__{state | last_sequence: System.os_time(:millisecond)}}
  end

  def handle_info({:metrics, ip, received, metrics}, %__MODULE__{sequence: expected, ip: ip} = state) do
    state =
      state
      |> update_metrics(metrics)
      |> resync_queue()

    info_log(state, "Unexpected sequence, got: #{received} expected: #{expected}")

    {:noreply, state}
  end

  def handle_info({:metrics, _other_ip, _received, _metrics}, state) do
    {:noreply, state}
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

  def handle_info({:joystick_update, %Joystick{} = joystick}, state) do
    state = maybe_enqueue(state, joystick)
    {:noreply, state}
  end

  def handle_info({:joystick_update, nil}, state) do
    {:noreply, state}
  end

  def handle_info(:time_sync, state) do
    binary = Commands.time_sync_binary()
    transmit_binary(binary, state)
    {:noreply, state}
  end

  def handle_info(:resync, state) do
    info_log(state, "Received resync command")
    {:noreply, resync_queue(state)}
  end

  def handle_info(:send_state, state) do
    notify_subscribers(state)
    {:noreply, state}
  end

  def handle_info(:tick, %__MODULE__{queue: queue, target: target, sequence: sequence} = state) do
    state =
      case :queue.out(queue) do
        {:empty, _} ->
          state

        {{:value, item}, rest} ->
          next_sequence = rem(sequence + 1, 256)

          binary =
            case item do
              command = %Command{} -> Commands.command_binary(command, target, next_sequence)
              joystick = %Joystick{} -> Commands.joystick_event_binary(joystick, next_sequence)
            end

          transmit_binary(binary, state)

          %{state | queue: rest, sequence: next_sequence}
      end

    state = check_connection(state)

    {:noreply, state}
  end

  def handle_info(data, socket) do
    warn_log(socket, "#{__MODULE__}: Unhandled info #{inspect(data)}")
    {:noreply, socket}
  end

  defp maybe_enqueue(%__MODULE__{queue: queue} = state, item) do
    queue =
      if :queue.len(queue) < @max_queue_len do
        :queue.in(item, queue)
      else
        queue
        |> :queue.drop()
        |> then(&:queue.in(item, &1))
      end

    %__MODULE__{state | queue: queue}
  end

  defp resync_queue(%__MODULE__{} = state) do
    debug_log(state, "Enquing resync")

    queue =
      Commands.list_commands(include_empty: true)
      |> Enum.reduce(:queue.new(), fn %Command{} = command, queue_acc -> :queue.in(command, queue_acc) end)

    %__MODULE__{state | queue: queue, last_sequence: System.os_time(:millisecond)}
    |> set_connection_state(:resync_send)
  end

  defp transmit_binary(binary, %__MODULE__{socket: socket, host: host} = state) when is_binary(binary) do
    debug_log(state, "Sending packet: #{inspect(binary)}")
    :ok = :gen_udp.send(socket, String.to_charlist(host), @target_port, binary)
  end

  defp check_connection(%__MODULE__{last_sequence: last_sequence} = state) do
    if System.os_time(:millisecond) - last_sequence > @sequence_timeout do
      set_connection_state(state, :not_responding)
    else
      state
    end
  end

  def set_connection_state(%__MODULE__{connection: connection} = state, connection), do: state

  def set_connection_state(%__MODULE__{connection: old} = state, new) do
    debug_log(state, "Changed connection from #{old} to #{new}")

    %__MODULE__{state | connection: new}
    |> notify_subscribers()
  end

  defp update_metrics(%__MODULE__{} = state, %TargetMetrics{fps: fps, wifi_strength: wifi_strength}) do
    %__MODULE__{state | fps: fps, wifi_strength: wifi_strength}
  end

  def debug_log(%__MODULE__{host: host}, message) do
    if Application.get_env(:tr33_control, :udp_debug, false) do
      Logger.debug("#{__MODULE__} #{inspect(host)}: #{message}")
    end
  end

  def info_log(%__MODULE__{host: host}, message) do
    Logger.info("#{__MODULE__} #{inspect(host)}: #{message}")
  end

  def warn_log(%__MODULE__{host: host}, message) do
    Logger.warn("#{__MODULE__} #{inspect(host)}: #{message}")
  end
end
