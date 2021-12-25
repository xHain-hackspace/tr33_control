defmodule Tr33ControlWeb.CommandsLive do
  use Tr33ControlWeb, :live_view
  require Logger

  alias Phoenix.LiveView.Socket
  alias Tr33Control.{Commands}
  alias Tr33Control.Commands.Command
  alias Tr33ControlWeb.{CommandComponent, CommandHeaderComponent, Components, Inputs}
  alias Tr33ControlWeb.Router.Helpers, as: Routes

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Commands.subscribe_commands()
    end

    socket =
      socket
      |> assign(command_types: Commands.command_types())

    {:ok, socket}
  end

  def handle_params(%{"index" => index}, _uri, socket) do
    socket =
      socket
      |> assign(active_command: String.to_integer(index))
      |> fetch()

    {:noreply, socket}
  end

  def handle_event("set_active_command", %{"index" => index}, socket) do
    socket =
      socket
      |> push_patch(to: Routes.commands_path(socket, :show, index))

    {:noreply, socket}
  end

  def handle_event("add_command", _, socket) do
    on_add_command(socket)
  end

  def handle_event("modal_close", _, %Socket{assigns: %{active_command: active_command}} = socket) do
    {:noreply, push_patch(socket, to: Routes.commands_path(socket, :show, active_command))}
  end

  def handle_event("modal_validate", _, socket) do
    # noop
    {:noreply, socket}
  end

  def handle_event("modal_submit", %{"command_type" => type}, %Socket{assigns: %{live_action: :new}} = socket) do
    index = Commands.count_commands()
    type = String.to_existing_atom(type)
    Commands.create_command(index, type, brightness: 100)

    socket =
      socket
      |> push_patch(to: Routes.commands_path(socket, :show, index))
      |> fetch()

    {:noreply, socket}
  end

  def handle_event("reset_commands", _, socket) do
    1..(Commands.count_commands() - 1)
    |> Enum.into([])
    |> Commands.delete_commands()

    Commands.create_command(0, :rainbow)

    socket =
      socket
      |> push_patch(to: Routes.commands_path(socket, :show, 0))
      |> fetch()

    {:noreply, socket}
  end

  def handle_event("keyup", %{"key" => "a"}, socket) do
    on_add_command(socket)
  end

  def handle_event("keyup", _, socket) do
    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  def handle_info({:command_update, command = %Command{}}, %Socket{} = socket) do
    send_update(CommandHeaderComponent, id: command.index, command: command)
    send_update(CommandComponent, id: "active_command", command: command)

    {:noreply, fetch(socket)}
  end

  def handle_info({:command_deleted, index}, %Socket{} = socket) do
    socket =
      if socket.assigns.active_command == index do
        socket
        |> push_patch(to: Routes.commands_path(socket, :show, Commands.count_commands() - 1))
      else
        socket
      end

    {:noreply, fetch(socket)}
  end

  def handle_info(data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled info #{inspect(data)}")
    {:noreply, socket}
  end

  defp fetch(socket) do
    socket
    |> assign(command_count: Commands.count_commands())
  end

  defp on_add_command(%Socket{assigns: %{active_command: active_command}} = socket) do
    {:noreply, push_patch(socket, to: Routes.commands_path(socket, :new, active_command))}
  end
end
