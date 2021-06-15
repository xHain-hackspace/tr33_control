defmodule Tr33Control.Commands.Preset do
  use Ecto.Schema
  alias Tr33Control.Commands.Command

  embedded_schema do
    field :name, :string
    field :default, :boolean, default: false

    embeds_many :commands, Command
  end
end
