defmodule Tr33ControlWeb.TargetsLive do
  use Tr33ControlWeb, :live_view
  require Logger
  alias Phoenix.LiveView.Socket
  alias Tr33Control.ESP
  alias Tr33Control.ESP.UDP
  alias Tr33ControlWeb.Display

  def mount(_, _, socket) do
    if connected?(socket) do
      UDP.subscribe()
      ESP.send_connection_states()
    end

    socket =
      socket
      |> assign(targets: %{})
      |> sort_targets()

    {:ok, socket}
  end

  def handle_event("resync", _, socket) do
    ESP.resync()
    {:noreply, socket}
  end

  def handle_event("reconnect", _, socket) do
    ESP.reconnect()
    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  def handle_info({:target_update, %UDP{host: host} = target}, socket) do
    socket =
      socket
      |> update(:targets, fn targets -> Map.put(targets, host, target) end)
      |> sort_targets()

    {:noreply, socket}
  end

  def handle_info(data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled info #{inspect(data)}")
    {:noreply, socket}
  end

  defp sort_targets(%Socket{assigns: %{targets: targets}} = socket) do
    sorted =
      targets
      |> Map.values()
      |> Enum.sort_by(fn %UDP{host: host} -> host end)

    assign(socket, sorted_targets: sorted)
  end

  defp class_for_target(%UDP{connection: conn}) when conn in [:ok, :waiting_for_response], do: "success"
  defp class_for_target(%UDP{connection: conn}) when conn in [:not_responding], do: "warning"
  defp class_for_target(%UDP{}), do: "danger"
end
