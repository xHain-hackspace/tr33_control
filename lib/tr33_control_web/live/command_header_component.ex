defmodule Tr33ControlWeb.CommandHeaderComponent do
  use Tr33ControlWeb, :live_component
  require Logger
  alias Phoenix.LiveView.Socket
  alias Tr33Control.{Commands, Targets}
  alias Tr33Control.Commands.Command
  alias Tr33ControlWeb.{Display, Inputs}

  def mount(socket) do
    socket =
      socket
      |> assign(active?: false)
      |> assign(command_targets: Targets.active_targets())

    {:ok, socket}
  end

  # update with new command state
  def update(assigns, %Socket{} = socket) do
    socket =
      socket
      |> assign(assigns)
      |> maybe_assign_active(Map.get(assigns, :active?))
      |> ensure_command()
      |> assign_brightness()

    {:ok, socket}
  end

  def handle_event("slider_change", %{"brightness" => brightness}, %Socket{} = socket) do
    Commands.update_command_param(socket.assigns.command.index, :brightness, String.to_integer(brightness))
    {:noreply, socket}
  end

  def handle_event("toggle_target", %{"target" => target_str}, %Socket{} = socket) do
    %{command: %Command{index: index}} = socket.assigns
    target = String.to_existing_atom(target_str)
    Commands.toggle_command_target(index, target)

    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  defp ensure_command(%Socket{assigns: %{command: _}} = socket), do: socket

  defp ensure_command(%Socket{assigns: %{id: id}} = socket) do
    socket
    |> assign(command: Commands.get_command(id))
  end

  def assign_brightness(%Socket{assigns: %{command: command}} = socket) do
    socket
    |> assign(:brightness_param, Commands.get_common_value_param(command, :brightness))
  end

  defp maybe_assign_active(%Socket{} = socket, nil), do: socket
  defp maybe_assign_active(%Socket{} = socket, value), do: assign(socket, active?: value)
end
