defmodule Tr33Control.Commands.StringParam do
  alias Protobuf.Field

  @enforce_keys [:name]
  defstruct [:value, :name]

  def new(struct, %Field{type: :string} = field_def) when is_struct(struct) do
    %__MODULE__{
      name: field_def.name,
      value: Map.fetch!(struct, field_def.name)
    }
  end

  def new(_, _), do: nil
end
