defmodule Tr33ControlWeb.Components do
  use Phoenix.Component
  require Logger

  def section(assigns) do
    ~H"""
      <div class="card border-secondary bg-body mb-3">
        <div class="card-header h4"><%= render_slot(@header) %></div>
        <div class="card-body">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    """
  end
end
