defmodule Tr33Control.UdpServer do
  use GenServer
  require Logger
  alias Tr33Control.{Commands, ESP}
  alias Tr33Control.Commands.Schemas.{WireMessage, TargetMetrics}

  @listen_port Application.compile_env!(:tr33_control, :udp_listen_port)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  def toggle_debug() do
    current = Application.get_env(:tr33_control, :udp_server_debug, false)
    new = not current
    Application.put_env(:tr33_control, :udp_server_debug, new)
    new
  end

  # -- GenServer callbacks -----------------------------------------------------

  def init(:ok) do
    {:ok, _} = :gen_udp.open(@listen_port, [:binary])
    Logger.info("#{__MODULE__}: Listening port #{@listen_port}")

    {:ok, %{}}
  end

  def handle_info({:udp, socket, address, port, protobuf}, state) do
    debug_log("Incoming command: #{inspect(protobuf)}, from: #{inspect(address)}:#{inspect(port)}")

    case WireMessage.decode(protobuf) do
      %WireMessage{message: {:target_metrics, %TargetMetrics{} = metrics}} ->
        ESP.handle_metrics(address, metrics)
        debug_log("Received target metrics #{inspect(metrics)}")

      %WireMessage{message: {:command_params, _}} ->
        debug_log("Received command params")
        Commands.create_command(protobuf)
        send_ack(socket, address, port)

      other ->
        Logger.warn("Received unexpected UDP data. Decoded as #{inspect(other)}")
    end

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
