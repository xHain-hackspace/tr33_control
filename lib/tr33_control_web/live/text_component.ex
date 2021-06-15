defmodule Tr33ControlWeb.TextComponent do
  use Tr33ControlWeb, :live_component
  alias Tr33Control.Commands.ValueParam

  def update(%{target: target, param: %ValueParam{} = param}, socket) do
    socket =
      socket
      |> assign(target: target)
      |> assign(value: param.value)
      |> assign(name: param.name)

    {:ok, socket}
  end

  def render(assigns) do
    # ~L"""
    #   # debouncd
    #   <button class="btn btn-secondary ms-2"><%= Display.humanize(name) %></button>
    #   <input type="text" class="form-control bg-dark text-body" name="<%= name %>" value="<%= value %>">
    # """
  end
end
