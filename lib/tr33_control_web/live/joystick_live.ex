defmodule Tr33ControlWeb.JoystickLive do
  use Tr33ControlWeb, :live_view
  require Logger
  alias Tr33Control.Joystick

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Joystick.subscribe()
    end

    socket =
      socket
      |> assign_state(Joystick.state())

    {:ok, socket}
  end

  def handle_event(event, data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled event #{inspect(event)} Data: #{inspect(data)}")
    {:noreply, socket}
  end

  def handle_info({:joystick_update, state}, socket) do
    socket =
      socket
      |> assign_state(state)

    {:noreply, socket}
  end

  def handle_info(data, socket) do
    Logger.warn("#{__MODULE__}: Unhandled info #{inspect(data)}")
    {:noreply, socket}
  end

  defp assign_state(socket, nil) do
    socket
    |> assign(class: "danger")
    |> assign(joystick_state: %Joystick{})
  end

  defp assign_state(socket, %Joystick{} = joystick_state) do
    socket
    |> assign(class: "success")
    |> assign(joystick_state: joystick_state)
  end
end
