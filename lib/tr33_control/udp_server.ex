defmodule Tr33Control.UdpServer do
  use GenServer
  require Logger
  alias Tr33Control.Commands.Schemas.FadeOutEvent
  alias Tr33Control.Commands.Schemas.FadeOut
  alias Tr33Control.{Commands, ESP, ColorPalettes}
  alias Tr33Control.Commands.Command

  alias Tr33Control.Commands.Schemas.{
    WireMessage,
    TargetMetrics,
    CommandParams,
    ColorPaletteResponse,
    RemoteLog
  }

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

  def handle_info({:udp, _socket, ip, port, <<r::8, g::8, b::8>>}, state) do
    debug_log("Incoming Color Packet #{r},#{g},#{b} from: #{inspect(ip)}:#{inspect(port)}")

    case Commands.get_command(7) do
      %Command{params: %CommandParams{enabled: true, type_params: {:calibrate, _}}} ->
        :noop

      _ ->
        Commands.create_command(7, :calibrate, enabled: true, brightness: 255)
    end

    Commands.update_command_param(7, :red, r)
    Commands.update_command_param(7, :green, g)
    Commands.update_command_param(7, :blue, b)

    {:noreply, state}
  end

  def handle_info({:udp, socket, ip, port, protobuf}, state) do
    debug_log("Incoming Packet: #{inspect(protobuf)}, from: #{inspect(ip)}:#{inspect(port)}")

    case WireMessage.decode(protobuf) do
      %WireMessage{message: {:target_metrics, %TargetMetrics{} = metrics}} ->
        ESP.handle_metrics(ip, metrics)
        debug_log("Received target metrics #{inspect(metrics)}")

      %WireMessage{message: {:command_params, %CommandParams{} = params}} ->
        debug_log("Received command params")

        try do
          Commands.create_command(params)
          send_ack(socket, ip, port)
        rescue
          error ->
            Sentry.capture_exception(error)
        end

      %WireMessage{message: {:color_palette_response, %ColorPaletteResponse{} = response}} ->
        debug_log("Received color_palette_response")
        ColorPalettes.handle_color_palette_response(response)

      %WireMessage{message: {:remote_log, %RemoteLog{} = log}} ->
        Logger.info("Remote Log: #{inspect(log.message)}")

      %WireMessage{message: {:fade_out_event, %FadeOutEvent{} = event}} ->
        debug_log("Received fade_out_event")
        ESP.broadcast_event(event)

      other ->
        Logger.warning("Received unexpected UDP data. Decoded as #{inspect(other)}")
    end

    {:noreply, state}
  rescue
    error ->
      msg = "UDPServer: Failed to decode #{inspect(protobuf)}\n #{inspect(error)}"
      Logger.error(msg)
      Sentry.capture_message(msg)
      {:noreply, state}
  end

  def handle_info(other, state) do
    Logger.warning(" Unexpected message: #{inspect(other)}")
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
