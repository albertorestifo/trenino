defmodule TswIo.Device do
  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Device.Input

  schema "devices" do
    field :name, :string

    has_many :inputs, Input

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
