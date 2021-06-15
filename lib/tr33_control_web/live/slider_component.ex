defmodule Tr33ControlWeb.SliderComponent do
  use Tr33ControlWeb, :live_component
  alias Tr33Control.Commands.ValueParam

  def update(%{target: target, param: %ValueParam{} = param}, socket) do
    socket =
      socket
      |> assign(target: target)
      |> assign(value: param.value)
      |> assign(min: param.min)
      |> assign(max: param.max)
      |> assign(step: param.step)
      |> assign(name: param.name)

    {:ok, socket}
  end

  def render(assigns) do
    ~L"""

      <div class="custom-vertical-range-container">
        <form phx-change="slider_change" phx-target="<%= @target %>" phx-auto-recover="ignore">
          <input
            type="range"
            class="form-range custom-vertical-range"
            phx-throttleX="30"            mix=<%= @min %>
            max=<%= @max %>
            value=<%= @value %>
            step=<%= @step %>
            name="<%= @name %>">
        </form>
      </div>
    """
  end
end
