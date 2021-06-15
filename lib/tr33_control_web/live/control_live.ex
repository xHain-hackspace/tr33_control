defmodule Tr33ControlWeb.ControlLive do
  use Tr33ControlWeb, :live_view
  require Logger

  alias Phoenix.LiveView.Socket
  alias Tr33Control.Commands
  alias Tr33Control.Commands.Command
  alias Tr33ControlWeb.{CommandComponent, PresetComponent, CommandHeaderComponent}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Commands.subscribe_commands()
      Commands.subscribe_presets()
    end

    socket =
      socket
      |> assign(active_command: 0)
      |> fetch()

    {:ok, socket}
  end

  def handle_event("set_active_command", %{"index" => index}, socket) do
    socket =
      socket
      |> assign(active_command: String.to_integer(index))

    {:noreply, socket}
  end

  def handle_event("add_command", _, socket) do
    %Command{index: index} =
      Commands.count_commands()
      |> Commands.create_command(:single_color, brightness: 0)

    socket =
      socket
      |> assign(active_command: index)
      |> fetch()

    {:noreply, socket}
  end

  def handle_event("delete_command", _, %Socket{} = socket) do
    socket.assigns.active_command
    |> Commands.delete_command()

    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  def handle_info({:command_update, command = %Command{}}, %Socket{} = socket) do
    send_update(CommandHeaderComponent, id: command.index, command: command)
    send_update(CommandComponent, id: :active_command, command: command)

    {:noreply, fetch(socket)}
  end

  def handle_info({:command_deleted, index}, %Socket{} = socket) do
    socket =
      if socket.assigns.active_command == index do
        assign(socket, :active_command, 0)
      else
        socket
      end

    {:noreply, fetch(socket)}
  end

  def handle_info({:preset_update, _name}, socket) do
    send_update(PresetComponent, id: :presets)

    {:noreply, socket}
  end

  def handle_info({:preset_deleted, _name}, socket) do
    send_update(PresetComponent, id: :presets)

    {:noreply, socket}
  end

  def handle_info(data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled info #{inspect(data)}")
    {:noreply, socket}
  end

  defp fetch(socket) do
    socket
    |> assign(command_count: Commands.count_commands())
  end
end
