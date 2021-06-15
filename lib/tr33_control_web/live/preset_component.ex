defmodule Tr33ControlWeb.PresetComponent do
  use Tr33ControlWeb, :live_component
  require Logger
  alias Phoenix.LiveView.Socket
  alias Tr33Control.Commands
  alias Tr33Control.Commands.{Command, Preset}
  alias Tr33ControlWeb.Display

  def mount(socket) do
    socket =
      socket
      |> assign(current_preset: nil)

    {:ok, socket}
  end

  def update(_assigns, %Socket{} = socket) do
    socket =
      socket
      |> assign(presets: Commands.list_presets())

    {:ok, socket}
  end

  def handle_event("create", %{"name" => name}, socket) do
    preset = Commands.create_preset(name)

    socket =
      socket
      |> assign(current_preset: preset)

    {:noreply, socket}
  end

  def handle_event("load", %{"name" => name}, socket) do
    socket =
      socket
      |> assign(current_preset: Commands.load_preset(name))

    {:noreply, socket}
  end

  def handle_event("update", _, %Socket{} = socket) do
    case socket.assigns do
      %{current_preset: %Preset{name: name}} -> Commands.create_preset(name)
      %{current_preset: nil} -> :noop
    end

    {:noreply, socket}
  end

  def handle_event("set_default", _, %Socket{} = socket) do
    case socket.assigns do
      %{current_preset: %Preset{name: name}} -> Commands.set_default_preset(name)
      %{current_preset: nil} -> :noop
    end

    {:noreply, socket}
  end

  def handle_event("delete", _, %Socket{} = socket) do
    case socket.assigns do
      %{current_preset: %Preset{name: name}} -> Commands.delete_preset(name)
      %{current_preset: nil} -> :noop
    end

    socket =
      socket
      |> assign(current_preset: nil)

    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  def handle_info(data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled info #{inspect(data)}")
    {:noreply, socket}
  end
end
