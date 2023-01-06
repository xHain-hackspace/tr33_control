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
      |> assign(current_preset: nil)
      |> assign(info: nil)

    {:ok, socket}
  end

  def handle_params(params, _, socket) do
    preset_name = Map.get(params, "name")

    socket =
      socket
      |> assign(current_preset: preset_name)
      |> fetch()

    {:noreply, socket}
  end

  def handle_event("new", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/presets/new")}
  end

  def handle_event("update", %{"name" => name}, socket) do
    {:noreply, push_patch(socket, to: ~p"/presets/#{name}/update")}
  end

  def handle_event("delete", %{"name" => name}, socket) do
    {:noreply, push_patch(socket, to: ~p"/presets/#{name}/delete")}
  end

  def handle_event("load", %{"name" => name}, socket) do
    Commands.load_preset(name)

    socket =
      socket
      |> assign(:info, %{text: "Preset #{inspect(name)} loaded", class: "success"})

    {:noreply, socket}
  end

  def handle_event("clone", %{"name" => name}, socket) do
    Commands.clone_preset(name)
    {:noreply, socket}
  end

  def handle_event("modal_close", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/presets")}
  end

  def handle_event("modal_validate", _, socket) do
    # noop
    {:noreply, socket}
  end

  def handle_event(
        "modal_submit",
        %{"name" => name},
        %Socket{assigns: %{live_action: :new}} = socket
      ) do
    name
    |> String.trim()
    |> Commands.create_preset()

    socket =
      socket
      |> assign(info: %{text: "#{inspect(name)} created", class: "success"})
      |> push_patch(to: ~p"/presets")

    {:noreply, socket}
  end

  def handle_event("modal_submit", _, %Socket{assigns: %{live_action: :update}} = socket) do
    name = socket.assigns.current_preset
    Commands.create_preset(name)

    socket =
      socket
      |> assign(info: %{text: "Preset #{inspect(name)} updated", class: "success"})
      |> push_patch(to: ~p"/presets")

    {:noreply, socket}
  end

  def handle_event("modal_submit", _, %Socket{assigns: %{live_action: :delete}} = socket) do
    name = socket.assigns.current_preset
    Commands.delete_preset(name)

    socket =
      socket
      |> assign(info: %{text: "Preset #{inspect(name)} deleted", class: "danger"})
      |> push_patch(to: ~p"/presets")

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
    |> assign(
      presets:
        Commands.list_presets()
        |> Enum.sort_by(fn %Preset{name: name} -> String.downcase(name) end)
    )
  end
end
