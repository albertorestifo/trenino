defmodule Trenino.Train.TrainIdentifier do
  @moduledoc """
  An equivalent simulator ObjectClass prefix owned by a train profile.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Train.Train

  @type t :: %__MODULE__{
          id: integer() | nil,
          identifier: String.t() | nil,
          train_id: integer() | nil,
          train: Train.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "train_identifiers" do
    field :identifier, :string

    belongs_to :train, Train

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = train_identifier, attrs) do
    train_identifier
    |> cast(attrs, [:identifier])
    |> update_change(:identifier, &String.trim/1)
    |> validate_required([:identifier])
    |> unique_constraint(:identifier)
  end
end
