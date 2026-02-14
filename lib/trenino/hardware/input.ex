defmodule Trenino.Hardware.Input do
  @moduledoc """
  Schema for device inputs (analog, button, or BLDC lever).

  ## Input Types

  - `:analog` - Analog input (e.g., potentiometer, lever). Requires sensitivity.
  - `:button` - Button input. Can be physical (pin 0-127) or virtual (pin 128-255).
  - `:bldc_lever` - BLDC motor haptic lever. Requires motor pins, encoder, and electrical params.

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
          input_type: :analog | :button | :bldc_lever,
          sensitivity: integer() | nil,
          debounce: integer() | nil,
          name: String.t() | nil,
          motor_pin_a: integer() | nil,
          motor_pin_b: integer() | nil,
          motor_pin_c: integer() | nil,
          motor_enable_a: integer() | nil,
          motor_enable_b: integer() | nil,
          encoder_cs: integer() | nil,
          pole_pairs: integer() | nil,
          voltage: integer() | nil,
          current_limit: integer() | nil,
          encoder_bits: integer() | nil,
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
    field :input_type, Ecto.Enum, values: [:analog, :button, :bldc_lever]
    field :sensitivity, :integer
    field :debounce, :integer
    field :name, :string

    # BLDC lever hardware parameters
    field :motor_pin_a, :integer
    field :motor_pin_b, :integer
    field :motor_pin_c, :integer
    field :motor_enable_a, :integer
    field :motor_enable_b, :integer
    field :encoder_cs, :integer
    field :pole_pairs, :integer
    field :voltage, :integer
    field :current_limit, :integer
    field :encoder_bits, :integer

    belongs_to :device, Device
    belongs_to :matrix, Matrix
    has_one :calibration, Calibration
    has_many :lever_bindings, LeverInputBinding

    timestamps(type: :utc_datetime)
  end

  @bldc_fields [
    :motor_pin_a,
    :motor_pin_b,
    :motor_pin_c,
    :motor_enable_a,
    :motor_enable_b,
    :encoder_cs,
    :pole_pairs,
    :voltage,
    :current_limit,
    :encoder_bits
  ]

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = input, attrs) do
    input
    |> cast(
      attrs,
      [:pin, :input_type, :sensitivity, :debounce, :name, :device_id, :matrix_id] ++
        @bldc_fields
    )
    |> validate_required([:input_type, :device_id, :pin])
    |> validate_by_input_type()
    |> validate_pin_range()
    |> foreign_key_constraint(:device_id)
    |> foreign_key_constraint(:matrix_id)
    |> unique_constraint([:device_id, :pin])
    |> unique_constraint(:device_id,
      name: :device_inputs_one_bldc_per_device,
      message: "already has a BLDC lever configured"
    )
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

      :bldc_lever ->
        changeset
        |> validate_required(@bldc_fields)
        |> validate_bldc_ranges()

      _ ->
        changeset
    end
  end

  @bldc_pin_fields [
    :motor_pin_a,
    :motor_pin_b,
    :motor_pin_c,
    :motor_enable_a,
    :motor_enable_b,
    :encoder_cs
  ]

  defp validate_bldc_ranges(changeset) do
    changeset =
      Enum.reduce(@bldc_pin_fields, changeset, fn field, cs ->
        validate_number(cs, field, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
      end)

    changeset
    |> validate_number(:pole_pairs, greater_than: 0, less_than_or_equal_to: 255)
    |> validate_number(:voltage, greater_than: 0, less_than_or_equal_to: 255)
    |> validate_number(:current_limit, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_number(:encoder_bits, greater_than: 0, less_than_or_equal_to: 255)
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
