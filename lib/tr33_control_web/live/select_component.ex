defmodule Tr33ControlWeb.SelectComponent do
  use Tr33ControlWeb, :live_component
  alias Tr33Control.Commands.EnumParam
  alias Tr33ControlWeb.Display

  def update(%{target: target, param: %EnumParam{} = param} = assigns, socket) do
    %{
      target: target,
      value: param.value,
      options: param.options,
      name: param.name,
      style: Map.get(assigns, :style, :command),
      tabindex: Map.get(assigns, :tabindex)
    }
    |> update(socket)
  end

  def update(%{target: target, value: value, options: options, name: name, style: style} = assigns, socket) do
    socket =
      socket
      |> assign(target: target)
      |> assign(value: value)
      |> assign(options: Enum.map(options, &sanetize_option/1))
      |> assign(name: name)
      |> assign(style: style)
      |> assign(tabindex: Map.get(assigns, :tabindex))

    {:ok, socket}
  end

  def render(assigns) do
    ~L"""
    <div class="btn-group">
      <button type="button" class="btn btn-<%= label_class(@style) %> text-start"><%= Display.humanize(@name) %></button>
      <form phx-change="select_change" phx-target="<%= @target %>" phx-auto-recover="ignore">
        <select class="form-select custom-select" name="<%= @name %>" <%= if @tabindex != nil, do: "tabindex=#{to_string(@tabindex)}" %>>
          <%= for {option_name, option_value} <- @options do %>
            <option value="<%= option_value %>" <%= if option_value == @value, do: "selected" %> >
              <%= Display.humanize(option_name) %>
            </option>
          <% end %>
        </select>
      </form>
    </div>
    """
  end

  defp label_class(:header), do: "secondary"
  defp label_class(:command), do: "dark"

  def sanetize_option({_name, _value} = option), do: option
  def sanetize_option(name_value), do: {name_value, name_value}
end
