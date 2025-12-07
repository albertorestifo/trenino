defmodule TswIo.Train.LeverInputBinding do
  @moduledoc """
  Schema for binding hardware inputs to train levers.

  Associates a device input with a lever configuration, enabling
  real-time translation of hardware movement to simulator lever values.

  Each lever config can have at most one input binding. The same input
  can be bound to different lever configs across different trains.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Hardware.Input
  alias TswIo.Train.LeverConfig

  @type t :: %__MODULE__{
          id: integer() | nil,
          lever_config_id: integer() | nil,
          input_id: integer() | nil,
          enabled: boolean(),
          lever_config: LeverConfig.t() | Ecto.Association.NotLoaded.t(),
          input: Input.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "lever_input_bindings" do
    field :enabled, :boolean, default: true

    belongs_to :lever_config, LeverConfig
    belongs_to :input, Input

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = binding, attrs) do
    binding
    |> cast(attrs, [:lever_config_id, :input_id, :enabled])
    |> validate_required([:lever_config_id, :input_id])
    |> foreign_key_constraint(:lever_config_id)
    |> foreign_key_constraint(:input_id)
    |> unique_constraint(:lever_config_id)
  end
end
