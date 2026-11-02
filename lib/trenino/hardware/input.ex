defmodule Trenino.Hardware.Input do
  @moduledoc """
  Schema for device inputs (analog or button).

  ## Input Types

  - `:analog` - Analog input (e.g., potentiometer, lever). Requires sensitivity.
  - `:button` - Button input. Can be physical (pin 0-127) or virtual (pin 128-255).

  Inputs created by an I2C input chip carry `i2c_module_id` and `i2c_channel` and
  also use virtual pins 128-255.

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

  alias Trenino.Hardware.Device
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Hardware.Matrix
  alias Trenino.Train.LeverInputBinding
  alias Trenino.VirtualJoystick.Mapping

  @type t :: %__MODULE__{
          id: integer() | nil,
          pin: integer(),
          input_type: :analog | :button,
          sensitivity: integer() | nil,
          debounce: integer() | nil,
          name: String.t() | nil,
          device_id: integer() | nil,
          matrix_id: integer() | nil,
          i2c_module_id: integer() | nil,
          i2c_channel: integer() | nil,
          device: Device.t() | Ecto.Association.NotLoaded.t(),
          matrix: Matrix.t() | Ecto.Association.NotLoaded.t() | nil,
          calibration: Calibration.t() | Ecto.Association.NotLoaded.t() | nil,
          lever_bindings: [LeverInputBinding.t()] | Ecto.Association.NotLoaded.t(),
          virtual_joystick_mapping: Mapping.t() | Ecto.Association.NotLoaded.t() | nil,
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
    belongs_to :i2c_module, I2cModule
    field :i2c_channel, :integer
    has_one :calibration, Calibration
    has_many :lever_bindings, LeverInputBinding
    has_one :virtual_joystick_mapping, Mapping

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = input, attrs) do
    input
    |> cast(attrs, [
      :pin,
      :input_type,
      :sensitivity,
      :debounce,
      :name,
      :device_id,
      :matrix_id,
      :i2c_module_id,
      :i2c_channel
    ])
    |> validate_required([:input_type, :device_id, :pin])
    |> validate_by_input_type()
    |> validate_pin_range()
    |> validate_i2c_channel()
    |> foreign_key_constraint(:device_id)
    |> foreign_key_constraint(:matrix_id)
    |> foreign_key_constraint(:i2c_module_id)
    |> unique_constraint([:i2c_module_id, :i2c_channel])
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

  # Virtual inputs (matrix buttons or I2C chip children) use pins 128-255,
  # physical inputs use pins 0-127. A virtual input has exactly one parent.
  defp validate_pin_range(changeset) do
    matrix_id = get_field(changeset, :matrix_id)
    i2c_module_id = get_field(changeset, :i2c_module_id)
    pin = get_field(changeset, :pin)

    cond do
      is_nil(pin) ->
        changeset

      not is_nil(matrix_id) and not is_nil(i2c_module_id) ->
        add_error(changeset, :i2c_module_id, "cannot be set together with a matrix")

      not is_nil(matrix_id) or not is_nil(i2c_module_id) ->
        validate_pin_in(
          changeset,
          pin,
          128..255,
          "must be between 128 and 255 for virtual inputs"
        )

      true ->
        validate_pin_in(changeset, pin, 0..127, "must be between 0 and 127 for physical inputs")
    end
  end

  defp validate_pin_in(changeset, pin, range, message) do
    if pin in range, do: changeset, else: add_error(changeset, :pin, message)
  end

  # i2c_channel is required exactly when i2c_module_id is set.
  defp validate_i2c_channel(changeset) do
    module_id = get_field(changeset, :i2c_module_id)
    channel = get_field(changeset, :i2c_channel)

    cond do
      not is_nil(module_id) and is_nil(channel) ->
        add_error(changeset, :i2c_channel, "can't be blank")

      is_nil(module_id) and not is_nil(channel) ->
        add_error(changeset, :i2c_channel, "requires an I2C module")

      true ->
        changeset
    end
  end

  @doc """
  Returns true if this input is virtual (a matrix button or an I2C chip input).
  """
  @spec virtual?(t()) :: boolean()
  def virtual?(%__MODULE__{} = input), do: not is_nil(input.matrix_id) or chip_input?(input)

  @doc """
  Returns true if this input is a child of an I2C input chip (MCP23017, ADS1115).
  """
  @spec chip_input?(t()) :: boolean()
  def chip_input?(%__MODULE__{i2c_module_id: nil}), do: false
  def chip_input?(%__MODULE__{}), do: true
end
