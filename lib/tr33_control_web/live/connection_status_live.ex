defmodule Tr33ControlWeb.ConnectionStatusLive do
  use Tr33ControlWeb, :live_view
  require Logger
  alias Phoenix.LiveView.Socket
  alias Tr33Control.ESP
  alias Tr33Control.ESP.UDP
  alias Tr33Control.Commands.Schemas.TargetMetrics
  alias Tr33ControlWeb.Display

  @tick_interval_ms 1000

  def mount(_, _, socket) do
    if connected?(socket) do
      UDP.subscribe()
      ESP.send_connection_states()
    end

    socket =
      socket
      |> assign(:now, System.os_time(:second))
      |> assign(targets: %{})
      |> sort_targets()

    :timer.send_interval(@tick_interval_ms, :tick)

    {:ok, socket}
  end

  def handle_event("resync", _, socket) do
    ESP.resync()
    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  def handle_info({:target_update, %UDP{ip: ip} = target}, socket) do
    socket =
      socket
      |> update(:targets, fn targets -> Map.put(targets, ip, target) end)
      |> assign(:now, System.os_time(:second))
      |> sort_targets()

    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    socket =
      socket
      |> assign(:now, System.os_time(:second))

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
      |> Enum.sort_by(fn %UDP{target_metrics: %TargetMetrics{name: name}} -> name end)

    assign(socket, sorted_targets: sorted)
  end

  defp class_for_target(%UDP{connection_status: status}) when status in [:ok, :started], do: "success"
  defp class_for_target(%UDP{connection_status: status}) when status in [:not_responding, :resync_sent], do: "warning"
  defp class_for_target(%UDP{}), do: "danger"
end
