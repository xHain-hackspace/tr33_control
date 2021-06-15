defmodule Tr33Control.Commands.ValueParam do
  alias Protobuf.Field

  @enforce_keys [:name]
  defstruct [:value, :name, min: 0, max: 255, step: 1]

  def new(struct, %Field{type: :int32, opts: opts} = field_def) when is_struct(struct) do
    %__MODULE__{
      name: field_def.name,
      value: Map.fetch!(struct, field_def.name)
    }
    |> add_max_value(opts)
  end

  def new(_, _), do: nil

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
end
