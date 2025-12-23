defmodule TswIo.Hardware.Matrix do
  @moduledoc """
  Schema for button matrix configurations.

  A matrix defines a grid of virtual buttons created from row and column pins.
  When a matrix is created, virtual button Input records are automatically
  generated for each cell in the grid.

  ## Virtual Pin Calculation

  Virtual pins for matrix buttons are calculated as:
  `128 + (row_index * num_cols + col_index)`

  This places them in the 128-255 range, separate from physical pins (0-127).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Hardware.Device
  alias TswIo.Hardware.Input
  alias TswIo.Hardware.Input.MatrixPin

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          device_id: integer() | nil,
          device: Device.t() | Ecto.Association.NotLoaded.t(),
          row_pins: [MatrixPin.t()] | Ecto.Association.NotLoaded.t(),
          col_pins: [MatrixPin.t()] | Ecto.Association.NotLoaded.t(),
          buttons: [Input.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "device_matrices" do
    field :name, :string

    belongs_to :device, Device
    has_many :row_pins, MatrixPin, where: [pin_type: :row], preload_order: [asc: :position]
    has_many :col_pins, MatrixPin, where: [pin_type: :col], preload_order: [asc: :position]
    has_many :buttons, Input

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = matrix, attrs) do
    matrix
    |> cast(attrs, [:name, :device_id])
    |> validate_required([:name, :device_id])
    |> validate_length(:name, min: 1, max: 100)
    |> foreign_key_constraint(:device_id)
  end

  @doc """
  Returns the number of rows in the matrix based on row_pins.
  """
  @spec num_rows(t()) :: integer()
  def num_rows(%__MODULE__{row_pins: pins}) when is_list(pins), do: length(pins)
  def num_rows(_), do: 0

  @doc """
  Returns the number of columns in the matrix based on col_pins.
  """
  @spec num_cols(t()) :: integer()
  def num_cols(%__MODULE__{col_pins: pins}) when is_list(pins), do: length(pins)
  def num_cols(_), do: 0

  @doc """
  Calculates the virtual pin for a given row and column index.
  """
  @spec virtual_pin(integer(), integer(), integer()) :: integer()
  def virtual_pin(row_index, col_index, num_cols) do
    128 + row_index * num_cols + col_index
  end
end
