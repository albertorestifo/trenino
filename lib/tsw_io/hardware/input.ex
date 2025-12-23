defmodule TswIo.Hardware.Input do
  @moduledoc """
  Schema for device inputs (analog or button).

  ## Input Types

  - `:analog` - Analog input (e.g., potentiometer, lever). Requires sensitivity.
  - `:button` - Button input. Can be physical (pin 0-127) or virtual (pin 128-255).

  ## Virtual Buttons

  Virtual buttons are created automatically when a Matrix is configured.
  They have:
  - `matrix_id` set to the parent matrix
  - `pin` in the range 128-255 (virtual pin)
  - `name` describing their position (e.g., "R0C1")

  Virtual buttons behave exactly like physical buttons but are hidden from
  the regular input configuration UI.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Hardware.Device
  alias TswIo.Hardware.Input.Calibration
  alias TswIo.Hardware.Matrix
  alias TswIo.Train.LeverInputBinding

  @type t :: %__MODULE__{
          id: integer() | nil,
          pin: integer(),
          input_type: :analog | :button,
          sensitivity: integer() | nil,
          debounce: integer() | nil,
          name: String.t() | nil,
          device_id: integer() | nil,
          matrix_id: integer() | nil,
          device: Device.t() | Ecto.Association.NotLoaded.t(),
          matrix: Matrix.t() | Ecto.Association.NotLoaded.t() | nil,
          calibration: Calibration.t() | Ecto.Association.NotLoaded.t() | nil,
          lever_bindings: [LeverInputBinding.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "device_inputs" do
    field :pin, :integer
    field :input_type, Ecto.Enum, values: [:analog, :button]
    field :sensitivity, :integer
    field :debounce, :integer
    field :name, :string

    belongs_to :device, Device
    belongs_to :matrix, Matrix
    has_one :calibration, Calibration
    has_many :lever_bindings, LeverInputBinding

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = input, attrs) do
    input
    |> cast(attrs, [:pin, :input_type, :sensitivity, :debounce, :name, :device_id, :matrix_id])
    |> validate_required([:input_type, :device_id, :pin])
    |> validate_by_input_type()
    |> validate_pin_range()
    |> foreign_key_constraint(:device_id)
    |> foreign_key_constraint(:matrix_id)
    |> unique_constraint([:device_id, :pin])
  end

  defp validate_by_input_type(changeset) do
    case get_field(changeset, :input_type) do
      :analog ->
        changeset
        |> validate_required([:sensitivity])
        |> validate_number(:sensitivity, greater_than: 0, less_than_or_equal_to: 10)

      :button ->
        changeset
        |> validate_required([:debounce])
        |> validate_number(:debounce, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)

      _ ->
        changeset
    end
  end

  # Virtual buttons (with matrix_id) use pins 128-255
  # Physical inputs use pins 0-127
  defp validate_pin_range(changeset) do
    matrix_id = get_field(changeset, :matrix_id)
    pin = get_field(changeset, :pin)

    cond do
      is_nil(pin) ->
        changeset

      # Virtual button (has matrix_id) - must be 128-255
      not is_nil(matrix_id) and pin >= 128 and pin < 256 ->
        changeset

      not is_nil(matrix_id) ->
        add_error(changeset, :pin, "must be between 128 and 255 for virtual buttons")

      # Physical input - must be 0-127
      pin >= 0 and pin < 128 ->
        changeset

      true ->
        add_error(changeset, :pin, "must be between 0 and 127 for physical inputs")
    end
  end

  @doc """
  Returns true if this input is a virtual button (part of a matrix).
  """
  @spec virtual?(t()) :: boolean()
  def virtual?(%__MODULE__{matrix_id: nil}), do: false
  def virtual?(%__MODULE__{}), do: true
end
