defmodule Tr33ControlWeb.Components do
  use Phoenix.Component
  require Logger

  def title(assigns) do
    assigns =
      assigns
      # |> assign(:title, Application.get_env(:tr33_control, :title, "Control"))
      |> assign(:title, "Led Control")
      |> assign_new(:class, fn -> nil end)

    ~H"""
      <%= @title %>
    """
  end

  def nav_item(%{conn: %Plug.Conn{} = conn, to: to, text: _} = assigns) do
    class = if String.starts_with?(conn.request_path, to), do: "nav-link active", else: "nav-link"

    assigns =
      assigns
      |> assign(:class, class)

    ~H"""
    <li class="nav-item">
      <a class={@class} href={@to}><%= @text %></a>
    </li>

    """
  end

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
