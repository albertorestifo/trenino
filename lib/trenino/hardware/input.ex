defmodule Trenino.Hardware.Input do
  @moduledoc """
  Schema for device inputs (analog or button).

  ## Input Types

  - `:analog` - Analog input (e.g., potentiometer, lever). Requires sensitivity.
    Read by the Arduino ADC (`sensor: :adc`, 0-1023) or by a magnetic angle sensor over
    I2C (see `Trenino.Hardware.AngleSensor`; `sensor: :mt6701` is 0-16383, firmware
    3.4.0). An angle-sensor input has an `i2c_address` and its `pin` is the report pin the
    device uses for it (`AngleSensor.report_pin/2`), not a physical pin.
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

  alias Trenino.Hardware.AngleSensor
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

  # An angle sensor's pin follows from its address, so a clash is reported on the address.
  defp unique_pin_constraint(changeset) do
    if AngleSensor.angle_sensor?(get_field(changeset, :sensor)) do
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

  @doc "The angle sensor spec for an input, or `nil` for an ADC input."
  @spec angle_sensor(t()) :: AngleSensor.t() | nil
  def angle_sensor(%__MODULE__{sensor: sensor}), do: AngleSensor.get(sensor)

  @doc "True when the input is read by a magnetic angle sensor over I2C."
  @spec angle_sensor?(t()) :: boolean()
  def angle_sensor?(%__MODULE__{sensor: sensor}), do: AngleSensor.angle_sensor?(sensor)

  @doc "Highest raw value the input's sensor reports."
  @spec max_raw_value(t()) :: pos_integer()
  def max_raw_value(%__MODULE__{} = input) do
    case angle_sensor(input) do
      %AngleSensor{max_raw: max_raw} -> max_raw
      nil -> 1023
    end
  end

  @doc """
  Where the input is wired, for labels: `"MT6701 at 0x06"` or `"Pin 3"`.
  """
  @spec location_label(t()) :: String.t()
  def location_label(%__MODULE__{i2c_address: address} = input) do
    case angle_sensor(input) do
      %AngleSensor{name: name} when is_integer(address) ->
        "#{name} at #{AngleSensor.format_address(address)}"

      _ ->
        "Pin #{input.pin}"
    end
  end

  # An angle sensor is an analog input on I2C: its address picks the report pin.
  defp validate_sensor(changeset) do
    sensor = get_field(changeset, :sensor)

    case {AngleSensor.get(sensor), get_field(changeset, :input_type)} do
      {nil, _} ->
        put_change(changeset, :i2c_address, nil)

      {%AngleSensor{} = spec, :analog} ->
        changeset
        |> validate_required([:i2c_address], message: "choose an address")
        |> validate_inclusion(:i2c_address, AngleSensor.addresses(spec),
          message: "must be #{address_list(spec)}"
        )
        |> put_report_pin(spec)

      {%AngleSensor{name: name}, _} ->
        add_error(changeset, :sensor, "#{name} is only for analog inputs")
    end
  end

  defp address_list(spec) do
    spec
    |> AngleSensor.addresses()
    |> Enum.map_join(" or ", &AngleSensor.format_address/1)
  end

  defp put_report_pin(changeset, spec) do
    case AngleSensor.report_pin(spec, get_field(changeset, :i2c_address)) do
      nil -> changeset
      pin -> put_change(changeset, :pin, pin)
    end
  end

  # Virtual buttons (with matrix_id) use pins 128-255
  # Physical inputs use pins 0-127
  # An angle sensor's report pin (240-247) is set from its address, not by the user.
  defp validate_pin_range(changeset) do
    if AngleSensor.angle_sensor?(get_field(changeset, :sensor)),
      do: changeset,
      else: validate_physical_or_virtual_pin(changeset)
  end

  defp validate_physical_or_virtual_pin(changeset) do
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
