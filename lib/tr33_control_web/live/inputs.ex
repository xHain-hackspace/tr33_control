defmodule Tr33ControlWeb.Inputs do
  use Phoenix.Component
  alias Tr33Control.Commands.{EnumParam, ValueParam}
  alias Tr33ControlWeb.Display

  def select(%{param: %EnumParam{} = param} = assigns) do
    %{
      value: param.value,
      options: param.options,
      name: param.name
    }
    |> Map.merge(assigns)
    |> Map.drop([:param])
    |> select()
  end

  def select(%{value: _, options: options, name: name} = assigns) do
    assigns =
      assigns
      |> assign_new(:style, fn -> :command end)
      |> assign_new(:tabindex, fn -> nil end)
      |> assign_new(:display_name, fn -> name end)
      |> assign_new(:size, fn -> nil end)
      |> assign_new(:target, fn -> nil end)
      |> assign_new(:width, fn -> 10 end)
      |> assign_new(:background, fn -> "dark" end)
      |> assign_new(:with_form, fn -> true end)
      |> assign_new(:humanize, fn -> true end)
      |> assign_new(:hook, fn -> nil end)
      |> assign_new(:id, fn -> name end)
      |> assign(:options, Enum.map(options, &sanetize_option/1))

    # <button type="button" class={ "btn btn-#{label_class(@style)} text-start" }><%= Display.humanize(@display_name) %></button>
    # <%= if @with_form do %>
    #   <form phx-change="select_change" phx-target={ @target } phx-auto-recover="ignore">
    # <% end %>
    ~H"""
      <div class="row flex-nowrap">

        <%= if @display_name != nil do %>
          <div class="col-auto">
            <label for={@id} class="col-form-label"><%= Display.humanize(@display_name) %></label>
          </div>
        <% end %>

        <div class="col-auto">
          <select
            class={"form-select bg-#{@background}"}
            style={"width: #{@width}rem;"}
            size={@size}
            name={@name}
            id={@id}
            data-pending-value={@value}
            {if @hook != nil, do: ['phx-hook': @hook], else: []}
            {if @tabindex != nil, do: [tabindex: to_string(@tabindex)], else: []}
            >
            <%= for {option_name, option_value} <- @options do %>
              <option value={ option_value } selected={ option_value == @value }  >
                <%= if @humanize, do: Display.humanize(option_name), else: option_name %>
              </option>
            <% end %>
          </select>
        </div>
      </div>
    """
  end

  def slider(%{target: _, param: %ValueParam{} = param} = assigns) do
    assigns =
      assigns
      |> assign(value: param.value)
      |> assign(min: param.min)
      |> assign(max: param.max)
      |> assign(step: param.step)
      |> assign(name: param.name)
      |> assign_new(:tabindex, fn -> nil end)

    ~H"""
    <div class="custom-vertical-range-container">
      <form phx-change="slider_change" phx-target={@target} phx-auto-recover="ignore">
        <input
          type="range"
          class="form-range custom-vertical-range"
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

  def label_class(:header), do: "secondary"
  def label_class(:command), do: "dark"

  # todo: this is fairly hacky and should be resolved further upstream
  def sanetize_option({_name, _value} = option), do: option
  def sanetize_option(name_value), do: {name_value, name_value}
end
