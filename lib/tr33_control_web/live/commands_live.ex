defmodule Tr33ControlWeb.CommandsLive do
  use Tr33ControlWeb, :live_view
  import Tr33ControlWeb.InputComponents
  require Logger

  alias Phoenix.LiveView.Socket
  alias Tr33Control.{Commands, ESP}
  alias Tr33Control.Commands.Command
  alias Tr33Control.ESP.UDP
  alias Tr33ControlWeb.{CommandComponent}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Commands.subscribe_commands()
      ESP.UDP.subscribe()
    end

    socket =
      socket
      |> assign(active_command_index: 0)

    {:ok, socket}
  end

  def handle_params(%{"index" => index}, _uri, socket) do
    socket =
      socket
      |> assign(active_command_index: String.to_integer(index))
      |> fetch()

    {:noreply, socket}
  end

  def handle_event("set_active_command", %{"index" => index}, socket) do
    socket =
      socket
      |> push_patch(to: ~p"/commands/#{index}")

    {:noreply, socket}
  end

  def handle_event("reset_commands", _, socket) do
    1..(Commands.count_commands() - 1)
    |> Enum.into([])
    |> Commands.delete_commands()

    Commands.create_command(0, :rainbow)

    socket =
      socket
      |> push_patch(to: ~p"/commands/0")
      |> fetch()

    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    Logger.warning("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  def handle_info({:command_update, command = %Command{}}, %Socket{} = socket) do
    send_update(CommandComponent, id: "active_command", command: command)

    {:noreply, fetch(socket)}
  end

  def handle_info({:command_deleted, index}, %Socket{} = socket) do
    socket =
      if socket.assigns.active_command == index do
        socket
        |> push_patch(to: ~p"/commands/#{Commands.count_commands() - 1}")
      else
        socket
      end

    {:noreply, fetch(socket)}
  end

  def handle_info({:target_update, %UDP{connection_status: :started}}, socket) do
    send_update(CommandComponent, id: "active_command")

    {:noreply, fetch(socket)}
  end

  def handle_info({:target_update, %UDP{connection_status: _}}, socket) do
    {:noreply, fetch(socket)}
  end

  def handle_info(data, socket) do
    Logger.warning("#{__MODULE__}: Unhandled info #{inspect(data)}")
    {:noreply, socket}
  end

  defp fetch(socket) do
    commands = Commands.list_commands(include_empty: true)

    socket
    |> assign(commands: commands)
  end

  # defp on_add_command(%Socket{assigns: %{active_command: active_command}} = socket) do
  #   {:noreply, push_patch(socket, to: ~p"/commands/#{active_command}/new")}
  # end
end
