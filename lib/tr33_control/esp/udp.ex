defmodule Tr33Control.ESP.UDP do
  use GenServer
  require Logger
  alias Tr33Control.{Commands, ESP, Joystick, Targets}
  alias Tr33Control.Commands.Command
  alias Tr33Control.Commands.Schemas.TargetMetrics

  defstruct [
    :socket,
    :queue,
    :target,
    :ip,
    :last_metrics,
    :connection_status,
    :target_metrics
  ]

  # todo: implement shutdown after some timeout

  @tick_interval_ms 30
  @max_queue_len 5
  @target_port 1337
  @pubsub_topic "udp_clients"
  @metrics_timeout 11_000
  @command_max_count Application.compile_env!(:tr33_control, :command_max_count)

  def subscribe(), do: Phoenix.PubSub.subscribe(Tr33Control.PubSub, @pubsub_topic)

  def notify_subscribers(%__MODULE__{} = state) do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @pubsub_topic, {:target_update, state})
    state
  end

  def handle_metrics(pid, %TargetMetrics{} = tm) when is_pid(pid) do
    GenServer.cast(pid, {:metrics, tm})
  end

  def start_link({_ip, %TargetMetrics{} = _target_metrics} = args) do
    GenServer.start_link(__MODULE__, args)
  end

  def toggle_debug() do
    current = Application.get_env(:tr33_control, :udp_debug, false)
    Application.put_env(:tr33_control, :udp_debug, not current)
  end

  def init({ip, target_metrics = %TargetMetrics{}}) do
    ESP.register_target(ip)

    local_port = Enum.random(5000..65535)
    {:ok, socket} = :gen_udp.open(local_port, [:binary])

    state =
      %__MODULE__{
        last_metrics: System.os_time(:millisecond),
        queue: :queue.new(),
        ip: ip,
        socket: socket
      }
      |> update_target_metrics(target_metrics)
      |> set_connection_state(:started)

    info_log(
      state,
      "Started process for device named #{inspect(target_metrics.name)}. Target: #{inspect(state.target)}. IP: #{inspect(state.ip)}. Sending UDP commands to port #{@target_port} using local port #{local_port}"
    )

    :timer.send_interval(@tick_interval_ms, :tick)

    ESP.subscribe()
    Commands.subscribe_commands()
    Joystick.subscribe()

    {:ok, state}
  end

  def handle_cast({:metrics, %TargetMetrics{} = tm}, %__MODULE__{target: target} = state) do
    debug_log(state, "Metrics received. Name: #{inspect(tm.name)}, Hashes: #{inspect(tm.hashes)}")

    if(length(tm.hashes) > @command_max_count) do
      warn_log(state, "Received more hashes than expected: #{inspect(tm.hashes)}")
    end

    resync_commands =
      tm.hashes
      |> Enum.take(@command_max_count)
      |> Enum.with_index()
      |> Enum.map(fn {received_hash, index} ->
        {received_hash, Commands.get_command_hash(index, target), index}
      end)
      |> Enum.filter(fn {received_hash, expected_hash, _index} -> received_hash != expected_hash end)
      |> Enum.map(fn {received_hash, expected_hash, index} = item ->
        info_log(
          state,
          "Hash mismatch for index #{index}. Received: #{inspect(received_hash)} Expected: #{inspect(expected_hash)}. Requeuing command"
        )

        item
      end)
      |> Enum.map(fn {_, _, index} ->
        Commands.get_command(index)
      end)

    new_connection_state = if Enum.empty?(resync_commands), do: :ok, else: :resync_sent

    state =
      %__MODULE__{state | last_metrics: System.os_time(:millisecond)}
      |> set_connection_state(new_connection_state)
      |> update_target_metrics(tm)

    state = Enum.reduce(resync_commands, state, fn command, state_acc -> maybe_enqueue(state_acc, command) end)

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

  def handle_info(:tick, %__MODULE__{queue: queue, target: target} = state) do
    state =
      case :queue.out(queue) do
        {:empty, _} ->
          state

        {{:value, item}, rest} ->
          binary =
            case item do
              command = %Command{} -> Commands.command_binary(command, target)
              joystick = %Joystick{} -> Commands.joystick_event_binary(joystick)
            end

          transmit_binary(binary, state)

          %{state | queue: rest}
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

    %__MODULE__{state | queue: queue}
    |> set_connection_state(:resync_sent)
  end

  defp transmit_binary(binary, %__MODULE__{socket: socket, ip: ip} = state) when is_binary(binary) do
    debug_log(state, "Sending packet: #{inspect(binary)}")
    :ok = :gen_udp.send(socket, {ip, @target_port}, binary)
  end

  defp check_connection(%__MODULE__{last_metrics: last_metrics} = state) do
    if System.os_time(:millisecond) - last_metrics > @metrics_timeout do
      set_connection_state(state, :not_responding)
    else
      state
    end
  end

  def set_connection_state(%__MODULE__{connection_status: status} = state, status), do: notify_subscribers(state)

  def set_connection_state(%__MODULE__{connection_status: old} = state, new) do
    debug_log(state, "Changed connection from #{old} to #{new}")

    %__MODULE__{state | connection_status: new}
    |> notify_subscribers()
  end

  defp update_target_metrics(%__MODULE__{} = state, %TargetMetrics{} = tm) do
    %__MODULE__{state | target_metrics: tm, target: Targets.get_target_from_metrics(tm)}
  end

  defp debug_log(%__MODULE__{target_metrics: %TargetMetrics{} = tm}, message) do
    if Application.get_env(:tr33_control, :udp_debug, false) do
      Logger.debug("#{__MODULE__} #{inspect(tm.name)}: #{message}")
    end
  end

  defp info_log(%__MODULE__{target_metrics: %TargetMetrics{} = tm}, message) do
    Logger.info("#{__MODULE__} #{inspect(tm.name)}: #{message}")
  end

  defp warn_log(%__MODULE__{target_metrics: %TargetMetrics{} = tm}, message) do
    Logger.warn("#{__MODULE__} #{inspect(tm.name)}: #{message}")
  end
end
