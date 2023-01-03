defmodule Tr33ControlWeb.InputComponents do
  use Phoenix.Component

  alias Tr33Control.Commands.{ValueParam, EnumParam}
  alias Tr33Control.Commands.{Command}
  alias Tr33ControlWeb.Display

  @doc "Renders selection button for commands"
  attr :command, Command, required: true
  attr :active, :boolean, required: true

  def command_button(assigns) do
    btn_class =
      case {assigns.active, Command.enabled?(assigns.command)} do
        {true, true} -> "btn-secondary the_chosen_one cmd_on"
        {true, false} -> "btn-secondary the_chosen_one"
        {false, true} -> "btn-outline-secondary cmd_on"
        {false, false} -> "btn-outline-light"
      end

    assigns = assign(assigns, btn_class: btn_class)

    ~H"""
    <button
      type="button"
      class={["btn one_cmd_btn", @btn_class]}
      phx-click="set_active_command"
      phx-value-index={@command.index}
    >
      <div class="the_cmd_index">Command <%= @command.index + 1 %></div>
      <div class="the_cmd_name"><%= Command.type(@command) |> Display.humanize() %></div>
      <div class="the_cmd_light"></div>
    </button>
    """
  end

  @doc "vertical input slider"

  attr :param, ValueParam, required: true
  attr :target, :string, default: nil

  def param_slider(%{param: %ValueParam{} = param} = assigns) do

    fader_class =
      case {param.type} do
        {:time} -> "in_seconds"
        {:percent} -> "in_percent"
        {:count} -> "in_pixel"
        {:color} -> "in_color"
      end

    assigns =
      assigns
      |> assign(value: param.value)
      |> assign(min: param.min)
      |> assign(max: param.max)
      |> assign(step: param.step)
      |> assign(name: param.name)
      |> assign(type: param.type)
      |> assign(palette: param.color_palette)
      |> assign(fader_class: fader_class)

    ~H"""
    <div class={["fader_display", @fader_class]}>


      <div class="param_name cmd_option_label">
        <%= Display.humanize(@name) %>
      </div>
      <div class="param_value">
        <!-- TODO: This is an example of how to use the param type -->
        <%= case @type do %>
          <% :percent -> %>
            <span class="all_7_segments">888</span>
            <span class="the_value_display"><%= Display.humanize(round(@value / 2.55)) %></span>
            <span class="the_unit">
              <div>%</div>
              <div>s</div>
              <div>px</div>
            </span>
          <% :time -> %>
            <span class="all_7_segments">8888</span>
            <span class="the_value_display"><%= Display.humanize(@value / 10) %></span>
            <span class="the_unit">
              <!-- TODO: choose css class: in_percent, in_seconds or in_pixel; could be higher in DOM ? -->
              <div>%</div>
              <div>s</div>
              <div>px</div>
            </span>
          <% :count -> %>
            <span class="all_7_segments">888</span>
            <span class="the_value_display"><%= Display.humanize(@value) %></span>
            <span class="the_unit">
              <div>%</div>
              <div>s</div>
              <div>px</div>
            </span>
          <% :color -> %>
            <div class="the_color_value" style={"background-color: #{hex_color_from_palette(@palette, @value)}"}>
            </div>
        <% end %>
      </div>
    </div>
    <form class={["fader_form", @fader_class]} phx-change="slider_change" phx-auto-recover="ignore" phx-target={@target}>
      <input type="range" class="the_fader" mix={@min} max={@max} value={@value} step={@step} name={@name} />
    </form>
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
    <form class="one_cmd_option" phx-change="select_change" phx-auto-recover="ignore" phx-target={@target}>
      <label for={@id} class="cmd_option_label label_for_select"><%= Display.humanize(@name) %></label>
      <select class="option_select" name={@name} id={@id} data-pending-value={@value}>
        <%= for option <- @options do %>
          <option value={option} selected={option == @value}>
            <%= Display.humanize(option) %>
          </option>
        <% end %>
      </select>
    </form>
    """
  end

  attr :name, :string, required: true
  attr :value, :boolean, required: true
  attr :target, :string, default: nil

  def switch(assigns) do
    ~H"""
    <form class="on_off_switch" phx-change="switch_change" phx-auto-recover="ignore" phx-target={@target}>
      <label class="cmd_option_label">Status</label>
      <input class="one_check_input" type="checkbox" name={@name} checked={@value} />
      <span class="the_unit on_off">
        <div>enabled</div>
        <div>disengaged</div>
      </span>
    </form>
    """
  end

  defp hex_color_from_palette(palette, color_index) do
    {r, g, b} = Tr33Control.ColorPalettes.color_from_palette(palette, color_index)

    "##{Integer.to_string(r, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(g, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(b, 16) |> String.pad_leading(2, "0")}"
  end
end
