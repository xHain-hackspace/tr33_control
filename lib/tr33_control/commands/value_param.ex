defmodule Tr33Control.Commands.ValueParam do
  alias Protobuf.Field
  alias Tr33Control.Commands
  alias Tr33Control.Commands.Command
  alias Tr33Control.Commands.Schemas.CommandParams

  @enforce_keys [:name]
  # valid types: percent, time, count, color
  defstruct [:value, :name, :display, min: 0, max: 255, step: 1, type: :percent, color_palette: nil]

  def new(struct, field_def, command \\ nil)

  def new(struct, %Field{type: :int32, opts: opts} = field_def, command) when is_struct(struct) do
    {command_type, color_palette} =
      case command do
        nil -> {nil, nil}
        %Command{params: %CommandParams{color_palette: palette}} -> {Command.type(command), palette}
      end

    %__MODULE__{
      name: field_def.name,
      value: Map.fetch!(struct, field_def.name),
      type: get_type(field_def.name, command_type),
      color_palette: color_palette
    }
    |> add_max_value(opts)
  end

  def new(_, _, _), do: nil

  defp add_max_value(%__MODULE__{} = param, opts) do
    opts
    |> Enum.find(&match?({[:nanopb, :max_size], _}, &1))
    |> case do
      nil ->
        param

      {[:nanopb, :max_size], size} ->
        %__MODULE__{param | max: size}
    end
  end

  def get_type(:fairy_index, _), do: :count
  def get_type(:color_temperature, _), do: :count
  def get_type(:count, _), do: :count
  def get_type(:period_100ms, _), do: :time
  def get_type(:flicker_delay, _), do: :time
  def get_type(:duration, _), do: :time
  def get_type(:color, _), do: :color
  def get_type(_, _), do: :percent
end
