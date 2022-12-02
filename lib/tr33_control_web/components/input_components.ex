defmodule Tr33ControlWeb.InputComponents do
  use Phoenix.Component

  alias Tr33Control.Commands.{ValueParam, EnumParam}
  alias Tr33Control.Commands
  alias Tr33Control.Commands.{Command}
  alias Tr33ControlWeb.Display

  @doc "Renders selection button for commands"
  attr :command, Command, required: true
  attr :active, :boolean, required: true

  def command_button(assigns) do
    btn_class =
      case {assigns.active, Command.enabled?(assigns.command)} do
        {true, _} -> "btn-secondary"
        {false, true} -> "btn-outline-secondary"
        {false, false} -> "btn-outline-light"
      end

    assigns = assign(assigns, btn_class: btn_class)

    ~H"""
    <button type="button" class={["btn p-5", @btn_class]} phx-click="set_active_command" phx-value-index={@command.index}>
      <%= @command.index + 1 %>
      <div><%= Command.type(@command) |> Display.humanize() %></div>
      <%!-- <%= if not Command.enabled?(@command) do %>
        <div>disabled</div>
      <% end %> --%>
    </button>
    """
  end

  @doc "vertical input slider"

  attr :param, ValueParam, required: true
  attr :target, :string, default: nil

  def param_slider(%{param: %ValueParam{} = param} = assigns) do
    assigns =
      assigns
      |> assign(value: param.value)
      |> assign(min: param.min)
      |> assign(max: param.max)
      |> assign(step: param.step)
      |> assign(name: param.name)

    ~H"""
    <div class="custom-vertical-range-container">
      <form phx-change="slider_change" phx-auto-recover="ignore" phx-target={@target}>
        <input
          type="range"
          class="form-range custom-vertical-range"
          mix={@min}
          max={@max}
          value={@value}
          step={@step}
          name={@name}
        />
      </form>
    </div>
    <div class="h5">
      <span class="badge bg-secondary my-2">
        <%= Display.humanize(@name) %>: <%= Display.humanize(@value) %>
      </span>
    </div>
    """
  end

  attr :param, EnumParam, required: true
  attr :target, :string, default: nil

  def param_select(%{param: %EnumParam{} = param} = assigns) do
    assigns =
      assigns
      |> assign(:name, param.name)
      |> assign(:id, "select_#{param.name}")
      |> assign(:options, param.options)
      |> assign(:value, param.value)

    ~H"""
    <form phx-change="select_change" phx-auto-recover="ignore" phx-target={@target}>
      <div class="row flex-nowrap">
        <div class="col-auto">
          <label for={@id} class="col-form-label"><%= Display.humanize(@name) %></label>
        </div>

        <div class="col-auto">
          <select class="form-select" name={@name} id={@id} data-pending-value={@value}>
            <%= for option <- @options do %>
              <option value={option} selected={option == @value}>
                <%= Display.humanize(option) %>
              </option>
            <% end %>
          </select>
        </div>
      </div>
    </form>
    """
  end

  attr :name, :string, required: true
  attr :value, :boolean, required: true
  attr :target, :string, default: nil

  def switch(assigns) do
    ~H"""
    <form phx-change="switch_change" phx-auto-recover="ignore" phx-target={@target}>
      <div class="form-check form-switch">
        <label class="form-check-label"><%= Display.humanize(@name) %></label>
        <input class="form-check-input" type="checkbox" name={@name} checked={@value} />
      </div>
    </form>
    """
  end
end
