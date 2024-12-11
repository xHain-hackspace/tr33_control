defmodule Tr33ControlWeb.PixelFunLive do
  use Tr33ControlWeb, :live_view
  import Tr33ControlWeb.InputComponents
  require Logger

  alias Phoenix.LiveView.Socket
  alias Tr33Control.{Commands, ESP}
  alias Tr33Control.Commands.Command
  alias Tr33Control.ESP.UDP
  alias Tr33ControlWeb.{CommandComponent}

  def mount(_params, %{"index" => index}, socket) do
    command = Commands.get_command(index)

    socket =
      socket
      |> assign(command: command)

    # |> assign(value_params: value_params)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    Hello world
    """
  end

  def handle_event(event, data, socket) do
    Logger.warning("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  def handle_info(data, socket) do
    Logger.warning("#{__MODULE__}: Unhandled info #{inspect(data)}")
    {:noreply, socket}
  end

  # defp on_add_command(%Socket{assigns: %{active_command: active_command}} = socket) do
  #   {:noreply, push_patch(socket, to: ~p"/commands/#{active_command}/new")}
  # end

  # def fetch()
end
