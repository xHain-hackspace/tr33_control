defmodule Tr33Control.Commands.Event do
  use Ecto.Schema
  import EctoEnum
  alias Ecto.Changeset
  alias Tr33Control.Commands.{Event}

  defenum EventTypes,
    gravity: 100,
    settings_update: 101

  @primary_key false
  embedded_schema do
    field :type, EventTypes
    field :data, {:array, :integer}, default: []
  end

  def changeset(event, params) do
    event
    |> Changeset.cast(params, [:type, :data])
    |> Changeset.validate_required([:type])
  end

  def to_binary(%Event{type: type, data: data}) do
    index = 0
    type_bin = EventTypes.__enum_map__() |> Keyword.get(type)
    data_bin = Enum.map(data, fn int -> <<int::size(8)>> end) |> Enum.join()
    <<index::size(8), type_bin::size(8), data_bin::binary>>
  end
end
