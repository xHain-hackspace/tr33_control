defmodule Tr33ControlWeb.PresetsLive do
  use Tr33ControlWeb, :live_view
  require Logger

  alias Phoenix.LiveView.Socket
  alias Tr33Control.Commands
  alias Tr33Control.Commands.Preset
  alias Tr33ControlWeb.{Components}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Commands.subscribe_presets()
    end

    socket =
      socket
      |> assign(selected_preset: nil)
      |> assign(info: nil)

    {:ok, socket}
  end

  def handle_params(_, _, socket) do
    {:noreply, fetch(socket)}
  end

  def handle_event(event, _, %Socket{assigns: %{selected_preset: nil}} = socket)
      when event in ["load", "update", "delete", "clone"] do
    socket =
      socket
      |> assign(info: %{text: "No preset selected", class: "warning"})

    {:noreply, socket}
  end

  def handle_event(event, _, socket) when event in ["new", "update", "delete"] do
    {:noreply, push_patch(socket, to: ~p"/presets/#{String.to_existing_atom(event)}")}
  end

  def handle_event("selected_preset_change", %{"name" => name}, socket) do
    socket =
      socket
      |> assign(selected_preset: name)

    {:noreply, socket}
  end

  def handle_event("load", _, socket) do
    on_load_preset(socket)
  end

  def handle_event("clone", _, %Socket{assigns: %{selected_preset: name}} = socket) do
    Commands.clone_preset(name)

    socket =
      socket
      |> assign(info: %{text: "#{inspect(name)} cloned", class: "success"})

    {:noreply, socket}
  end

  def handle_event("modal_close", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/presets")}
  end

  def handle_event("modal_validate", _, socket) do
    # noop
    {:noreply, socket}
  end

  def handle_event("modal_submit", %{"name" => name}, %Socket{assigns: %{live_action: :new}} = socket) do
    name
    |> String.trim()
    |> Commands.create_preset()

    socket =
      socket
      |> assign(info: %{text: "#{inspect(name)} created", class: "success"})
      |> assign(selected_preset: nil)
      |> push_patch(to: ~p"/presets")

    {:noreply, socket}
  end

  def handle_event("modal_submit", _, %Socket{assigns: %{live_action: :update, selected_preset: name}} = socket) do
    Commands.create_preset(name)

    socket =
      socket
      |> assign(info: %{text: "#{inspect(name)} updated", class: "success"})
      |> assign(selected_preset: nil)
      |> push_patch(to: ~p"/presets")

    {:noreply, socket}
  end

  def handle_event("modal_submit", _, %Socket{assigns: %{live_action: :delete, selected_preset: name}} = socket) do
    Commands.delete_preset(name)

    socket =
      socket
      |> assign(info: %{text: "#{inspect(name)} deleted", class: "danger"})
      |> assign(selected_preset: nil)
      |> push_patch(to: ~p"/presets")

    {:noreply, socket}
  end

  def handle_event("keyup", %{"key" => "Enter"}, %Socket{assigns: %{live_action: :index}} = socket) do
    on_load_preset(socket)
  end

  def handle_event(
        "keyup",
        %{"key" => key},
        %Socket{assigns: %{live_action: :index, selected_preset: name, presets: presets}} = socket
      )
      when key in ["ArrowDown", "ArrowUp"] do
    current_index =
      case presets |> Enum.map(& &1.name) |> Enum.find_index(&(&1 == name)) do
        nil -> -1
        n -> n
      end

    next_index =
      case key do
        "ArrowDown" -> current_index + 1
        "ArrowUp" -> max(current_index - 1, 0)
      end

    next_name =
      case Enum.at(presets, next_index) do
        nil -> name
        %Preset{name: next} -> next
      end

    socket =
      socket
      |> assign(selected_preset: next_name)

    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  def handle_info({:preset_update, _name}, socket) do
    {:noreply, fetch(socket)}
  end

  def handle_info({:preset_deleted, _name}, socket) do
    {:noreply, fetch(socket)}
  end

  def handle_info(data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled info #{inspect(data)}")
    {:noreply, socket}
  end

  defp fetch(socket) do
    socket
    |> assign(presets: Commands.list_presets() |> Enum.sort_by(fn %Preset{name: name} -> String.downcase(name) end))
  end

  defp on_load_preset(%Socket{assigns: %{selected_preset: name}} = socket) do
    Commands.load_preset(name)

    socket =
      socket
      |> assign(info: %{text: "#{inspect(name)} loaded", class: "success"})

    {:noreply, socket}
  end
end
