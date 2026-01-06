defmodule Trenino.Train.Train do
  @moduledoc """
  Schema for train configurations.

  Each train represents a simulator vehicle identified by its unique identifier
  derived from the train's ObjectClass values. A train can have multiple elements
  (levers, buttons, etc.) that map to simulator API endpoints.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Train.Element

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          identifier: String.t() | nil,
          elements: [Element.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "trains" do
    field :name, :string
    field :description, :string
    field :identifier, :string

    has_many :elements, Element

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = train, attrs) do
    train
    |> cast(attrs, [:name, :description, :identifier])
    |> validate_required([:name, :identifier])
    |> unique_constraint(:identifier)
  end
end
