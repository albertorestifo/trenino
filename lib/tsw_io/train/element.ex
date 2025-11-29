defmodule TswIo.Train.Element do
  @moduledoc """
  Schema for train elements.

  An element represents a control on the train (lever, button, etc.) that can
  be configured to map hardware inputs to simulator API endpoints.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Train.Train
  alias TswIo.Train.LeverConfig

  @type element_type :: :lever

  @type t :: %__MODULE__{
          id: integer() | nil,
          train_id: integer() | nil,
          type: element_type() | nil,
          name: String.t() | nil,
          train: Train.t() | Ecto.Association.NotLoaded.t(),
          lever_config: LeverConfig.t() | nil | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "train_elements" do
    field :type, Ecto.Enum, values: [:lever]
    field :name, :string

    belongs_to :train, Train
    has_one :lever_config, LeverConfig

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = element, attrs) do
    element
    |> cast(attrs, [:type, :name, :train_id])
    |> validate_required([:type, :name])
    |> foreign_key_constraint(:train_id)
  end
end
