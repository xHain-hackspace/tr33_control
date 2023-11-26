defmodule Tr33Control.Commands.ColorParam do
  alias Protobuf.Field

  @enforce_keys [:name]
  defstruct [:value, :name]

  def new(struct, %Field{type: :bytes} = field_def) when is_struct(struct) do
    %__MODULE__{
      name: field_def.name,
      value: Map.fetch!(struct, field_def.name)
    }
  end

  def new(_, _), do: nil

  def hex_string(%__MODULE__{value: <<r, g, b>>}) do
    "##{int_to_hex(r)}#{int_to_hex(g)}#{int_to_hex(b)}"
  end

  defp int_to_hex(int) do
    Integer.to_string(int, 16) |> String.pad_leading(2, "0")
  end
end
