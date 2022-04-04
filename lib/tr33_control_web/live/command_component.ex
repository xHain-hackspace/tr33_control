defmodule Tr33ControlWeb.CommandComponent do
  use Tr33ControlWeb, :live_component
  require Logger
  alias Phoenix.LiveView.Socket
  alias Tr33Control.{Commands, Targets}
  alias Tr33Control.Commands.{Command, EnumParam, ValueParam}
  alias Tr33ControlWeb.Router.Helpers, as: Routes
  alias Tr33ControlWeb.{Display, Inputs, Components}

  def mount(socket) do
    socket =
      socket
      |> assign(command_targets: Targets.get_targets() |> Map.keys())
      |> assign(modifiers_active: true)

    {:ok, socket}
  end

  # index update, current command is already at that index. Do nothing
  def update(%{index: index}, %Socket{assigns: %{command: %Command{index: index}}} = socket) do
    {:ok, socket}
  end

  # index update, current command is differnt or there is none at all. Fetch it
  def update(%{index: index}, %Socket{} = socket) do
    command = Commands.get_command(index)
    {:ok, update_command(socket, command)}
  end

  # command update, its index matches the active one. Update
  def update(%{command: %Command{index: i} = command}, %Socket{assigns: %{command: %Command{index: i}}} = socket) do
    {:ok, update_command(socket, command)}
  end

  # command update, but its index does not match the active one. Ignore
  def update(%{command: _}, socket) do
    {:ok, socket}
  end

  def handle_event("palette_change", %{"color_palette" => color_palette}, %Socket{} = socket) do
    %Command{index: index} = socket.assigns.command

    Commands.update_command_param(index, :color_palette, String.to_existing_atom(color_palette))

    {:noreply, socket}
  end

  def handle_event("strip_index_change", %{"strip_index" => strip_index}, %Socket{} = socket) do
    %Command{index: index} = socket.assigns.command

    Commands.update_command_param(index, :strip_index, String.to_integer(strip_index))

    {:noreply, socket}
  end

  def handle_event("param_select_change", %{"_target" => [name_str]} = data, %Socket{} = socket) do
    %Command{index: index} = socket.assigns.command

    name = String.to_existing_atom(name_str)
    value = Map.fetch!(data, name_str) |> String.to_existing_atom()

    update_param(index, name, value)

    {:noreply, socket}
  end

  def handle_event("slider_change", %{"_target" => [name_str]} = data, %Socket{} = socket) do
    %Command{index: index} = socket.assigns.command

    name = String.to_existing_atom(name_str)
    value = Map.fetch!(data, name_str) |> String.to_integer()

    update_param(index, name, value)

    {:noreply, socket}
  end

  def handle_event("increment_command_index", _, %Socket{} = socket) do
    %Command{index: old} = socket.assigns.command
    new = old + 1

    Commands.swap_commands(old, new)

    socket = push_patch(socket, to: Routes.commands_path(socket, :show, new))

    {:noreply, socket}
  end

  def handle_event("decrement_command_index", _, %Socket{} = socket) do
    %Command{index: old} = socket.assigns.command
    new = old - 1

    Commands.swap_commands(old, new)

    socket = push_patch(socket, to: Routes.commands_path(socket, :show, new))

    {:noreply, socket}
  end

  def handle_event("delete_command", _, %Socket{} = socket) do
    socket.assigns.command.index
    |> Commands.delete_command()

    {:noreply, socket}
  end

  def handle_event("clone_command", _, %Socket{} = socket) do
    socket.assigns.command.index
    |> Commands.clone_command()

    {:noreply, socket}
  end

  def handle_event("toggle_modifiers", _, %Socket{} = socket) do
    modifier_count =
      socket.assigns.command
      |> Commands.get_modifier_params()
      |> Enum.count()

    socket =
      socket
      |> assign(:modifiers_active, modifier_count != 0 || not socket.assigns.modifiers_active)

    {:noreply, socket}
  end

  def handle_event("add_modifier", %{"name" => name_str}, %Socket{} = socket) do
    name = String.to_existing_atom(name_str)
    Commands.add_modifier(socket.assigns.command, name)

    {:noreply, socket}
  end

  def handle_event("delete_modifier", %{"name" => name_str}, %Socket{} = socket) do
    name = String.to_existing_atom(name_str)
    Commands.delete_modifier(socket.assigns.command, name)

    {:noreply, socket}
  end

  def handle_event("update_modifier", %{"name" => name_str} = data, %Socket{} = socket) do
    name = String.to_existing_atom(name_str)

    field_updates =
      data
      |> Map.drop(["name", "_target"])
      |> Enum.map(fn
        {"movement_type" = name, val} -> {String.to_existing_atom(name), String.to_existing_atom(val)}
        {name, val} -> {String.to_existing_atom(name), parse_int(val)}
      end)
      |> Enum.into(%{})

    Commands.update_modifier(socket.assigns.command, name, field_updates)
    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  defp update_command(%Socket{} = socket, command) do
    modifier_params = Commands.get_modifier_params(command)

    socket
    |> assign(command: command)
    |> assign(value_params: Commands.list_value_params(command))
    |> assign(enum_params: Commands.list_enum_params(command))
    |> assign(color_palette_param: Commands.get_common_enum_param(command, :color_palette))
    |> assign(strip_index_options: Commands.get_strip_index_options(command))
    |> assign(modifier_names: Commands.list_modifier_names(command))
    |> assign(modifier_params: modifier_params)
    |> assign(modifiers_active: socket.assigns.modifiers_active || length(modifier_params) > 0)
  end

  defp update_param(index, name, value) do
    Commands.update_command_param(index, name, value)
  end

  defp modifier_active?(command, name) do
    Commands.get_modifier(command, name) != nil
  end

  defp parse_int(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> 0
    end
  end
end
