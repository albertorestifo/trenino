defmodule Trenino.Train.DisplayBinding do
  @moduledoc """
  Binds a simulator endpoint to an I2C display module.

  The endpoint value is formatted via `format_string` and sent as segment bytes
  on every change. Supported format tokens:
  - `{value}` — raw value as string
  - `{value:.Nf}` — float formatted to N decimal places
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Hardware.I2cModule
  alias Trenino.Train.Train

  @type t :: %__MODULE__{
          id: integer() | nil,
          train_id: integer() | nil,
          i2c_module_id: integer() | nil,
          name: String.t() | nil,
          endpoint: String.t() | nil,
          format_string: String.t(),
          enabled: boolean(),
          script_id: integer() | nil,
          train: Train.t() | Ecto.Association.NotLoaded.t(),
          i2c_module: I2cModule.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "train_display_bindings" do
    field :name, :string
    field :endpoint, :string
    field :format_string, :string, default: "{value}"
    field :enabled, :boolean, default: true
    field :script_id, :integer

    belongs_to :train, Train
    belongs_to :i2c_module, I2cModule

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = binding, attrs) do
    binding
    |> cast(attrs, [:train_id, :i2c_module_id, :name, :endpoint, :format_string, :enabled])
    |> validate_required([:train_id, :i2c_module_id, :endpoint, :format_string])
    |> validate_length(:name, max: 100)
    |> validate_length(:format_string, min: 1, max: 200)
    |> foreign_key_constraint(:train_id)
    |> foreign_key_constraint(:i2c_module_id)
    |> unique_constraint([:train_id, :i2c_module_id])
  end
end
