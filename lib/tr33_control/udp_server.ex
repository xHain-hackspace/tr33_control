defmodule Tr33Control.UdpServer do
  use GenServer
  require Logger
  alias Tr33Control.{Commands, ESP}

  @listen_port Application.fetch_env!(:tr33_control, :udp_listen_port)
  @sequence_header "SEQ"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  def toggle_debug() do
    current = Application.get_env(:tr33_control, :udp_server_debug, false)
    Application.put_env(:tr33_control, :udp_server_debug, not current)
  end

  # -- GenServer callbacks -----------------------------------------------------

  def init(:ok) do
    {:ok, socket} = :gen_udp.open(@listen_port, [:binary])
    Logger.info("#{__MODULE__}: Listening on port #{@listen_port}")

    state = %{
      socket: socket
    }

    {:ok, state}
  end

  def handle_info({:udp, _socket, address, port, <<@sequence_header, sequence::size(8)>>}, state) do
    debug_log("Incoming sequence \"#{sequence}\" from #{inspect(address)}:#{inspect(port)}")
    ESP.handle_udp_sequence(address, port, sequence)
    {:noreply, state}
  end

  def handle_info({:udp, socket, address, port, protobuf}, state) do
    debug_log("Incoming command: #{inspect(protobuf)}, from: #{inspect(address)}:#{inspect(port)}")

    command = Commands.create_command(protobuf)

    debug_log("Valid command: #{inspect(command)}")

    send_ack(socket, address, port)

    {:noreply, state}
  end

  def handle_info(other, state) do
    Logger.warn(" Unexpected message: #{inspect(other)}")
    {:noreply, state}
  end

  def send_ack(socket, address, port) do
    :gen_udp.send(socket, address, port, <<42>>)
  end

  def debug_log(message) do
    if Application.get_env(:tr33_control, :udp_server_debug, false) do
      Logger.debug("#{__MODULE__}: #{message}")
    end
  end
end
