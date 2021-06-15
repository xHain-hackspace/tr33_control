defmodule Tr33Control.Commands.Command do
  use Ecto.Schema

  alias Protobuf.Field
  alias Tr33Control.Commands.Schemas.{CommandParams, Modifier}

  @max_index Application.compile_env!(:tr33_control, :command_max_index)

  @primary_key false
  embedded_schema do
    # internal
    field :index, :integer, default: 0
    field :targets, {:array, Tr33Control.Atom}, default: Application.compile_env!(:tr33_control, :targets)

    # protobuf
    field :params, :map
    field :encoded, :binary
  end

  def new(index, type, common_values \\ []) when is_atom(type) and index < @max_index do
    params = CommandParams.new([index: index] ++ common_values)

    %__MODULE__{index: index, params: params}
    |> new_type_params(type)
  end

  def new(protobuf) when is_binary(protobuf) do
    params = %CommandParams{} = CommandParams.decode(protobuf)

    %__MODULE__{
      index: params.index,
      params: params
    }
  end

  def disabled(index) do
    # todo: create this once at compile_time
    new(index, :single_color, enabled: false)
  end

  def new_type_params(%__MODULE__{params: params} = command, type) do
    %Protobuf.OneOfField{fields: fields} = CommandParams.defs(:field, :type_params)
    %Field{type: {:msg, type_full}} = Enum.find(fields, &match?(%Field{name: ^type}, &1))
    type_params = apply(type_full, :new, [])

    %__MODULE__{command | params: %CommandParams{params | type_params: {type, type_params}}}
  end

  def encode(%__MODULE__{params: %CommandParams{} = params} = command) do
    %__MODULE__{command | encoded: CommandParams.encode(params)}
  end

  def get_field_def(name) when is_atom(name) do
    CommandParams.defs(:field, name)
  end

  def list_type_field_defs(%__MODULE__{params: %CommandParams{type_params: {_, type_params}}}) do
    type_params
    |> Map.from_struct()
    |> Map.keys()
    |> Enum.map(&apply(type_params.__struct__, :defs, [:field, &1]))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.fnum)
  end

  def list_modifier_field_defs() do
    %Modifier{}
    |> Map.from_struct()
    |> Map.drop([:field_index])
    |> Map.keys()
    |> Enum.map(&Modifier.defs(:field, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.fnum)
  end

  def type(%__MODULE__{params: %CommandParams{type_params: {type, _}}}), do: type

  def type_params(%__MODULE__{params: %CommandParams{type_params: {_, type_params}}}), do: type_params
end
