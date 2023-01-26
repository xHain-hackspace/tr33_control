defmodule Tr33ControlWeb.Components do
  use Phoenix.Component
  require Logger

  def title(assigns) do
    assigns =
      assigns
      |> assign(:title, Application.get_env(:tr33_control, :title, "Control"))
      # |> assign(:title, "Led Control")
      |> assign_new(:class, fn -> nil end)

    ~H"""
    <%= @title %>
    """
  end

  def section_card(assigns) do
    assigns =
      assigns
      |> assign_new(:buttons, fn -> [] end)

    ~H"""
    <div class="status_wrap card border-secondary bg-body mb-3">
      <div class="card-header text-nowrapss">
        <div class="d-flex justify-content-start align-items-center">
          <h4 class="m-0" style="width: 13rem;"><%= render_slot(@header) %></h4>
          <%= render_slot(@buttons) %>
        </div>
      </div>
      <div class="card-body">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def section(assigns) do
    ~H"""
    <h4 class="my-4"><%= render_slot(@header) %></h4>
    <%= render_slot(@inner_block) %>
    """
  end

  def modal(assigns) do
    assigns =
      assigns
      |> assign_new(:target, fn -> nil end)
      |> assign_new(:title, fn -> "" end)
      |> assign_new(:button_text, fn -> "OK" end)
      |> assign_new(:button_class, fn -> "primary" end)

    ~H"""
    <div class="modal">
      <div
        class="modal-dialog"
        role="document"
        phx-capture-click="modal_close"
        phx-window-keyup="modal_close"
        phx-key="escape"
        phx-target={@target}
      >
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title"><%= @title %></h5>
            <button type="button" class="btn btn-close" phx-click="modal_close"></button>
          </div>

          <form phx-submit="modal_submit" phx-change="modal_validate">
            <div class="modal-body">
              <%= render_slot(@inner_block) %>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" phx-click="modal_close">Cancel</button>
              <button type="submit" class={"btn btn-#{@button_class}"}><%= @button_text %></button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <div class="modal-backdrop"></div>
    """
  end

  def list_select(%{options: _, active: _} = assigns) do
    assigns =
      assigns
      |> assign_new(:event, fn -> "list_select_change" end)

    ~H"""
    <div class="presets_list ">
      <%= for option <- @options do %>
        <button
          type="button"
          class={"presets_item #{if @active == option, do: "active"}"}
          style="line-height: 0.6;"
          phx-click={@event}
          phx-value-name={option}
        >
          <%= option %>
        </button>
      <% end %>
    </div>
    """
  end
end
