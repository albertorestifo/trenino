defmodule TswIo.Hardware.Input do
  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Hardware.Device
  alias TswIo.Hardware.Input.Calibration
  alias TswIo.Hardware.Input.MatrixPin
  alias TswIo.Train.LeverInputBinding

  schema "device_inputs" do
    # Pin is nullable - null for matrix inputs, required for analog/button
    field :pin, :integer
    field :input_type, Ecto.Enum, values: [:analog, :button, :matrix]
    field :sensitivity, :integer
    field :debounce, :integer

    belongs_to :device, Device
    has_one :calibration, Calibration
    has_many :lever_bindings, LeverInputBinding
    has_many :matrix_pins, MatrixPin

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(%__MODULE__{} = input, attrs) do
    input
    |> cast(attrs, [:pin, :input_type, :sensitivity, :debounce, :device_id])
    |> validate_required([:input_type, :device_id])
    |> validate_by_input_type()
    |> unique_constraint([:device_id, :pin])
  end

  defp validate_by_input_type(changeset) do
    case get_field(changeset, :input_type) do
      :analog ->
        changeset
        |> validate_required([:pin, :sensitivity])
        |> validate_number(:pin, greater_than_or_equal_to: 0, less_than: 128)
        |> validate_number(:sensitivity, greater_than: 0, less_than_or_equal_to: 10)

      :button ->
        changeset
        |> validate_required([:pin, :debounce])
        |> validate_number(:pin, greater_than_or_equal_to: 0, less_than: 128)
        |> validate_number(:debounce, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)

      :matrix ->
        # Matrix inputs don't have a single pin - pins are in matrix_pins table
        # Ensure pin is null for matrix inputs
        changeset
        |> validate_pin_is_null()

      _ ->
        changeset
    end
  end

  defp validate_pin_is_null(changeset) do
    case get_field(changeset, :pin) do
      nil -> changeset
      _ -> add_error(changeset, :pin, "must be null for matrix inputs")
    end
  end
end
