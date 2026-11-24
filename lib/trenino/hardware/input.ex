defmodule Trenino.Hardware.Input do
  @moduledoc """
  Schema for device inputs (analog or button).

  ## Input Types

  - `:analog` - Analog input (e.g., potentiometer, lever). Requires sensitivity.
    Read by the Arduino ADC (`sensor: :adc`, 0-1023) or by an MT6701 magnetic angle
    sensor over I2C (`sensor: :mt6701`, 0-16383, firmware 3.4.0). An MT6701 input has an
    `i2c_address` (0x06 or 0x46) and its `pin` is the report pin the device uses for it
    (see `mt6701_report_pin/1`), not a physical pin.
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

  alias Trenino.Hardware.Device
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Hardware.Matrix
  alias Trenino.Train.LeverInputBinding

  @type t :: %__MODULE__{
          id: integer() | nil,
          pin: integer(),
          input_type: :analog | :button,
          sensor: :adc | :mt6701,
          i2c_address: integer() | nil,
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
    field :sensor, Ecto.Enum, values: [:adc, :mt6701], default: :adc
    field :i2c_address, :integer
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
    |> cast(attrs, [
      :pin,
      :input_type,
      :sensor,
      :i2c_address,
      :sensitivity,
      :debounce,
      :name,
      :device_id,
      :matrix_id
    ])
    |> validate_sensor()
    |> validate_required([:input_type, :device_id, :pin])
    |> validate_by_input_type()
    |> validate_pin_range()
    |> foreign_key_constraint(:device_id)
    |> foreign_key_constraint(:matrix_id)
    |> unique_pin_constraint()
  end

  # An MT6701's pin follows from its address, so a clash is reported on the address.
  defp unique_pin_constraint(changeset) do
    if get_field(changeset, :sensor) == :mt6701 do
      unique_constraint(changeset, [:device_id, :pin],
        error_key: :i2c_address,
        message: "is already used by another sensor on this device"
      )
    else
      unique_constraint(changeset, [:device_id, :pin])
    end
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

  @mt6701_report_pins %{0x06 => 240, 0x46 => 241}

  @doc """
  I2C addresses an MT6701 can answer at: 0x06 (factory) and 0x46 (saved in its EEPROM).
  """
  @spec mt6701_addresses() :: [integer()]
  def mt6701_addresses, do: Map.keys(@mt6701_report_pins) |> Enum.sort()

  @doc """
  The pin an MT6701 input reports under. The device sends the sensor's readings with this
  pin, so it must not clash with physical pins (0-127) or matrix buttons (128-191).
  """
  @spec mt6701_report_pin(integer()) :: integer() | nil
  def mt6701_report_pin(address), do: Map.get(@mt6701_report_pins, address)

  @doc "Highest raw value the input's sensor reports."
  @spec max_raw_value(t()) :: pos_integer()
  def max_raw_value(%__MODULE__{sensor: :mt6701}), do: 16_383
  def max_raw_value(%__MODULE__{}), do: 1023

  # An MT6701 is an analog input on I2C: its address picks the report pin.
  defp validate_sensor(changeset) do
    case {get_field(changeset, :sensor), get_field(changeset, :input_type)} do
      {:mt6701, :analog} ->
        changeset
        |> validate_required([:i2c_address])
        |> validate_inclusion(:i2c_address, mt6701_addresses(),
          message: "must be 0x06 or 0x46"
        )
        |> put_mt6701_pin()

      {:mt6701, _} ->
        add_error(changeset, :sensor, "MT6701 is only for analog inputs")

      _ ->
        put_change(changeset, :i2c_address, nil)
    end
  end

  defp put_mt6701_pin(changeset) do
    case mt6701_report_pin(get_field(changeset, :i2c_address)) do
      nil -> changeset
      pin -> put_change(changeset, :pin, pin)
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

      get_field(changeset, :sensor) == :mt6701 ->
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
