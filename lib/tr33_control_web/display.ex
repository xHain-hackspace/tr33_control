defmodule Tr33ControlWeb.Display do
  alias Tr33Control.Commands
  alias Tr33Control.Commands.{Command, ValueParam, EnumParam, Preset}
  alias Tr33Control.Commands.Schemas.{CommandParams}

  def command_target(target) when is_atom(target) do
    target
    |> Atom.to_string()
    |> String.capitalize()
  end

  def target_active?(%Command{targets: targets}, target) do
    target in targets
  end

  def param_sliders(%Command{params: params}) do
    %{__struct__: struct} = params
    apply(struct, :defs, [])
  end

  def name(%ValueParam{name: name}), do: humanize(name)
  def name(%EnumParam{name: name}), do: humanize(name)

  def value(%ValueParam{value: value}), do: humanize(value)
  def value(%EnumParam{value: value}), do: humanize(value)

  def humanize(name) do
    name
    |> to_string()
    |> String.split("_")
    |> Enum.reject(&match?("100ms", &1))
    |> Enum.map(&String.capitalize/1)
    |> Enum.map(&String.replace(&1, "Ms", "[ms]"))
    |> Enum.join(" ")
  end

  def current_preset(nil), do: "Load Preset"
  def current_preset(%Preset{name: name}), do: name

  def preset_option(%Preset{name: name, default: true}), do: "#{name} [default]"
  def preset_option(%Preset{name: name}), do: name

  def strip_index_name(%Command{params: %CommandParams{strip_index: value}}, options) do
    {name, _value} = Enum.find(options, &match?({_name, ^value}, &1))
    humanize(name)
  end

  def modifier_name(command, modifier) do
    Commands.modifier_name(command, modifier)
    |> humanize()
  end

  def unix_timestamp(timestamp_str) when is_binary(timestamp_str) do
    {timestamp_int, _} = Integer.parse(timestamp_str)

    DateTime.from_unix!(timestamp_int)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end

  def unix_timestamp(nil), do: "-"

  def ip(nil), do: "-"
  def ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
end
