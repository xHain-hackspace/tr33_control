defmodule Tr33ControlWeb.StatusLive do
  use Tr33ControlWeb, :live_view
  require Logger
  alias Tr33ControlWeb.Components

  def handle_event(event, data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  def handle_info(data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled info #{inspect(data)}")
    {:noreply, socket}
  end
end
