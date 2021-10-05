defmodule Tr33ControlWeb.SliderComponent do
  use Tr33ControlWeb, :live_component
  alias Tr33Control.Commands.ValueParam
  alias Tr33ControlWeb.Display

  def update(%{target: target, param: %ValueParam{} = param} = assigns, socket) do
    socket =
      socket
      |> assign(target: target)
      |> assign(value: param.value)
      |> assign(min: param.min)
      |> assign(max: param.max)
      |> assign(step: param.step)
      |> assign(name: param.name)
      |> assign(tabindex: Map.get(assigns, :tabindex))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="custom-vertical-range-container">
      <form phx-change="slider_change" phx-target={@target} phx-auto-recover="ignore">
        <input
          type="range"
          class="form-range custom-vertical-range"
          phx-throttleX="30"
          {if @tabindex != nil, do: [tabindex: to_string(@tabindex)]}
          mix={ @min }
          max={ @max }
          value={ @value }
          step={ @step }
          name={ @name }
        >
      </form>
    </div>
    <div class="h5">
      <span class="badge bg-secondary my-2">
        <%= Display.humanize(@name) %>: <%= Display.humanize(@value) %>
      </span>
    </div>

    """
  end
end
