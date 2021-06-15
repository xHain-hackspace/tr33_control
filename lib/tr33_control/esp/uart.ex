defmodule Tr33Control.ESP.UART do
  use GenServer
  require Logger
  alias Tr33Control.Commands
  alias Tr33Control.Commands.Command

  # these values have to match with the config in the firmware
  @baudrate 921_600
  # @baudrate 1_000_000
  @serial_header 42
  @serial_ready_to_send "AA" |> Base.decode16!()
  @serial_clear_to_send "BB" |> Base.decode16!()
  @serial_request_resync "CC" |> Base.decode16!()
  @rts_max_wait_ms 100

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  def toggle_debug() do
    current = Application.get_env(:tr33_control, :uart_debug, false)
    Application.put_env(:tr33_control, :uart_debug, not current)
  end

  def send_rts() do
    GenServer.cast(__MODULE__, :send_rts)
  end

  # -- GenServer callbacks -----------------------------------------------------

  def init(_) do
    {:ok, uart_pid} = Circuits.UART.start_link()

    serial_port = Application.fetch_env!(:tr33_control, :serial_port)
    result = Circuits.UART.open(uart_pid, serial_port, speed: @baudrate, active: true)

    Logger.info(
      "#{__MODULE__}: Connection to serial port #{serial_port}, baudrate: #{@baudrate}. Result: #{inspect(result)}"
    )

    :ok = Circuits.UART.configure(uart_pid, framing: Circuits.UART.Framing.None)

    state = %{
      uart_pid: uart_pid,
      queue: :queue.new(),
      target: :tr33,
      last_rts: 0
    }

    Commands.subscribe()

    {:ok, state}
  end

  def handle_cast(:send_rts, state) do
    send_rts(state, true)
    {:noreply, state}
  end

  def handle_info({:command_update, %Command{} = command}, %{target: target} = state) do
    binary = Commands.binary_for_target(command, target)

    state =
      state
      |> Map.update!(:queue, &:queue.in(binary, &1))
      |> send_rts(false)

    {:noreply, state}
  end

  def handle_info({:circuits_uart, _, @serial_clear_to_send}, %{queue: queue} = state) do
    debug_log("RECEIVED CTS")

    state = %{state | last_rts: 0}

    {{:value, binary}, queue_rest} = :queue.out(queue)
    binary_size = byte_size(binary)
    header = <<@serial_header::size(8), binary_size::size(8)>>

    debug_log("SENDING ONE COMMAND WITH #{binary_size} BYTES")

    packet = :erlang.iolist_to_binary([header | [binary]])
    send_packet(state, packet)

    state =
      case :queue.len(queue_rest) do
        0 -> state
        _ -> send_rts(state, true)
      end

    {:noreply, %{state | queue: queue_rest}}
  end

  def handle_info({:circuits_uart, _, bytes}, state) do
    left_size = (byte_size(bytes) - 1) * 8

    case bytes do
      <<_::size(left_size), @serial_request_resync>> ->
        debug_log("#{__MODULE__}:  RECEIVED RESYNC REQUEST")

        state =
          state
          |> resync_queue()
          |> send_rts(false)

        {:noreply, state}

      _ ->
        Logger.warn("#{__MODULE__}:  RECEIVED UNEXPECTED: #{inspect(bytes)}")
        {:noreply, state}
    end
  end

  def handle_info({_, _}, state), do: {:noreply, state}

  defp send_packet(%{uart_pid: uart_pid}, paket) do
    debug_log("SENDING #{inspect(paket)}")

    :ok = Circuits.UART.write(uart_pid, paket)
  end

  defp send_rts(state, true), do: do_send_rts(state)

  defp send_rts(%{last_rts: last_rts} = state, false) do
    if System.os_time(:millisecond) > last_rts + @rts_max_wait_ms do
      do_send_rts(state)
    else
      state
    end
  end

  defp do_send_rts(%{uart_pid: uart_pid} = state) do
    debug_log("SENDING RTS #{inspect(@serial_ready_to_send)}")

    Circuits.UART.write(uart_pid, @serial_ready_to_send)
    %{state | last_rts: System.os_time(:millisecond)}
  end

  defp resync_queue(state) do
    debug_log("RESYNC REQUEUE COMMANDS")

    queue =
      Commands.list_commands()
      |> Enum.reduce(:queue.new(), fn %Command{encoded: encoded}, queue_acc -> :queue.in(encoded, queue_acc) end)

    %{state | queue: queue}
  end

  def debug_log(message) do
    if Application.get_env(:tr33_control, :uart_debug, false) do
      Logger.debug("#{__MODULE__}: #{message}")
    end
  end
end
