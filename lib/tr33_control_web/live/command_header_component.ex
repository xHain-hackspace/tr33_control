defmodule Tr33ControlWeb.CommandHeaderComponent do
  use Tr33ControlWeb, :live_component
  require Logger
  alias Phoenix.LiveView.Socket
  alias Tr33Control.Commands
  alias Tr33Control.Commands.Command
  alias Tr33ControlWeb.Display

  # update with new command state
  def update(%{command: command}, %Socket{} = socket) do
    socket =
      socket
      |> assign(:command, command)
      |> assign(:brightness_param, Commands.get_common_value_param(command, :brightness))

    {:ok, socket}
  end

  # update without new command state, command already in session. Don't do anything
  def update(_, %Socket{assigns: %{command: _}} = socket) do
    {:ok, socket}
  end

  # update without command in session, fetch it
  def update(%{id: index} = assigns, socket) do
    assigns
    |> Map.put(:command, Commands.get_command(index))
    |> update(socket)
  end

  def handle_event("slider_change", %{"brightness" => brightness}, %Socket{} = socket) do
    Commands.update_command_param(socket.assigns.command.index, :brightness, String.to_integer(brightness))
    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end
end
