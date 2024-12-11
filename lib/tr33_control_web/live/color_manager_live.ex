defmodule Tr33ControlWeb.ColorManagerLive do
  use Tr33ControlWeb, :live_view
  import Tr33ControlWeb.InputComponents
  require Logger

  alias Phoenix.LiveView.Socket
  alias Tr33Control.Commands

  def mount(_params, %{"index" => index}, socket) do
    command = Commands.get_command(index)

    socket
    |> assign(index: index)
    |> assign(color_params: Commands.get_common_color_params(command))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    Hello Color
    """
  end
end

# <div class="color_wrap">
#       <%= for param <- @color_params do %>
#         <.color_display hex_color={ColorParam.hex_string(param)} />
#       <% end %>
#     </div>
