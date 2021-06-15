defmodule Tr33Control.Commands.EnumParam do
  alias Protobuf.Field
  alias Tr33Control.Commands.Schemas

  @enforce_keys [:name, :options]
  defstruct [:value, :name, :options]

  def new(struct, %Field{type: {:enum, type}} = field_def) when is_struct(struct) do
    %__MODULE__{
      name: field_def.name,
      value: Map.fetch!(struct, field_def.name),
      options: apply(type, :atoms, [])
    }
    |> override(type)
  end

  def new(_, _), do: nil

  defp override(%__MODULE__{} = param, Schemas.ColorPalette) do
    blacklist =
      ~w(LAVA CLOUD OCEAN_BREEZE RGI RETRO2 ANALOGOUS ANOTHER_SUNSET LANDSCAPE LANDSCAPE2 IB15 COLORFULL BLACK_BLUE_MAGENTA_WHITE BLACK_MAGENTA_RED BLACK_RED_MAGENTA_YELLOW )a

    options = Schemas.ColorPalette.atoms() |> Enum.reject(&(&1 in blacklist))

    %__MODULE__{param | options: options}
  end

  defp override(param, _), do: param
end
