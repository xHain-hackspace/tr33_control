defmodule Tr33ControlWeb.LayoutComponents do
  use Phoenix.Component

  def section_card(assigns) do
    assigns =
      assigns
      |> assign_new(:buttons, fn -> [] end)

    ~H"""
    <div class="card border-secondary bg-body">
      <div class="card-header text-nowrapss">
        <div class="justify-content-start align-items-center">
          <h4 class="m-0" style="width: 13rem;"><%= render_slot(@header) %></h4>
        </div>
      </div>
      <div class="card-body">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
