defmodule TswIo.Hardware.Input.MatrixPin do
  @moduledoc """
  Schema for matrix row/column pin configuration.

  Each matrix has multiple row pins and column pins that define
  the button grid. The virtual pin for a button press is calculated as:
  `128 + (row_index * num_cols + col_index)`
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Hardware.Matrix

  @type pin_type :: :row | :col

  @type t :: %__MODULE__{
          id: integer() | nil,
          matrix_id: integer() | nil,
          pin_type: pin_type(),
          pin: integer(),
          position: integer(),
          matrix: Matrix.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "device_input_matrix_pins" do
    field :pin_type, Ecto.Enum, values: [:row, :col]
    field :pin, :integer
    field :position, :integer

    belongs_to :matrix, Matrix

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = matrix_pin, attrs) do
    matrix_pin
    |> cast(attrs, [:pin_type, :pin, :position, :matrix_id])
    |> validate_required([:pin_type, :pin, :position, :matrix_id])
    |> validate_number(:pin, greater_than_or_equal_to: 0, less_than: 128)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:matrix_id)
    |> unique_constraint([:matrix_id, :pin_type, :position])
  end
end
