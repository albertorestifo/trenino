defmodule Trenino.Hardware.StepperAxis do
  @moduledoc "Persistent electrical configuration; never persists a live position or reference."
  use Ecto.Schema
  import Ecto.Changeset
  alias Trenino.Hardware.I2cModule
  alias Trenino.Serial.Protocol.StepperConfiguration
  @type t :: %__MODULE__{}
  @motion_fields Map.keys(Map.from_struct(%StepperConfiguration{}))
  schema "hardware_stepper_axes" do
    belongs_to :device, Trenino.Hardware.Device
    field :name, :string
    field :axis_index, :integer, default: 0
    field :driver, Ecto.Enum, values: [:adafruit_motor_shield], default: :adafruit_motor_shield

    field :mode, Ecto.Enum,
      values: [:x27_six_state, :full_step, :half_step],
      default: :x27_six_state

    field :shield_address, :integer, default: 96
    field :motor_port, :integer, default: 1
    field :reverse, :boolean, default: false
    field :idle_behavior, Ecto.Enum, values: [:hold, :release], default: :hold
    field :host_loss_behavior, Ecto.Enum, values: [:hold, :release], default: :release

    field :reference_strategy, Ecto.Enum,
      values: [:host_reference, :internal_stop],
      default: :host_reference

    field :min_position, :integer, default: 0
    field :max_position, :integer, default: 720
    field :max_speed, :integer, default: 100
    field :acceleration, :integer, default: 200
    field :home_direction, :integer, default: -1
    field :home_steps, :integer, default: 900
    field :home_speed, :integer, default: 100
    field :home_timeout_ms, :integer, default: 12_000
    field :home_position, :integer, default: 0
    field :watchdog_ms, :integer, default: 1000
    field :home_backoff, :integer, default: 10
    field :startup_reference, Ecto.Enum, values: [:manual, :home_on_connect], default: :manual
    field :commissioned, :boolean, default: false
    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = axis, attrs) do
    axis
    |> cast(
      parse_address(attrs),
      @motion_fields ++ [:name, :axis_index, :startup_reference, :commissioned]
    )
    |> validate_required([:name, :device_id, :axis_index] ++ @motion_fields)
    |> validate_length(:name, max: 100)
    |> validate_inclusion(:axis_index, [0, 1])
    |> validate_ranges()
    |> validate_configuration()
    |> clear_commissioning()
    |> validate_startup()
    |> foreign_key_constraint(:device_id)
    |> unique_constraint([:device_id, :axis_index])
    |> unique_constraint([:device_id, :motor_port])
  end

  @spec to_protocol_config(t()) :: StepperConfiguration.t()
  def to_protocol_config(%__MODULE__{} = axis),
    do: struct(StepperConfiguration, Map.take(Map.from_struct(axis), @motion_fields))

  def motion_changed?(%Ecto.Changeset{} = cs),
    do: Enum.any?([:axis_index | @motion_fields], &Map.has_key?(cs.changes, &1))

  def auto_home?(%__MODULE__{} = a),
    do:
      a.commissioned and a.startup_reference == :home_on_connect and
        a.reference_strategy == :internal_stop and a.idle_behavior == :hold

  defp parse_address(attrs) do
    key = if Map.has_key?(attrs, "shield_address"), do: "shield_address", else: :shield_address

    case Map.get(attrs, key) do
      "0x" <> _ = value ->
        case I2cModule.parse_i2c_address(value) do
          {:ok, address} -> Map.put(attrs, key, address)
          :error -> attrs
        end

      _ ->
        attrs
    end
  end

  defp validate_configuration(cs) do
    c = cs |> apply_changes() |> to_protocol_config()

    cs =
      if StepperConfiguration.valid?(c),
        do: cs,
        else:
          add_error(
            cs,
            :max_speed,
            "invalid electrical configuration: check ranges, limits and home parameters"
          )

    if c.reference_strategy == :internal_stop and is_integer(c.home_speed) and c.home_speed > 0 and
         is_integer(c.home_steps) and is_integer(c.home_backoff) and is_integer(c.home_timeout_ms) and
         c.home_timeout_ms <= ceil(1000 * (c.home_steps + c.home_backoff) / c.home_speed) + 500 do
      add_error(cs, :home_timeout_ms, "must exceed sweep and backoff duration plus 500 ms")
    else
      cs
    end
  end

  defp validate_ranges(cs) do
    cs =
      Enum.reduce(
        [
          {:shield_address, 96, 119},
          {:motor_port, 1, 2},
          {:min_position, -1_000_000, 1_000_000},
          {:max_position, -1_000_000, 1_000_000},
          {:max_speed, 1, 200},
          {:acceleration, 1, 10_000},
          {:watchdog_ms, 100, 60_000},
          {:home_steps, 1, 65_535},
          {:home_speed, 1, 200},
          {:home_timeout_ms, 1, 60_000},
          {:home_backoff, 0, 65_534},
          {:home_position, -1_000_000, 1_000_000}
        ],
        cs,
        fn {field, low, high}, acc ->
          validate_number(acc, field, greater_than_or_equal_to: low, less_than_or_equal_to: high)
        end
      )

    cs |> validate_inclusion(:home_direction, [-1, 1]) |> validate_relationships()
  end

  defp validate_relationships(cs) do
    c = apply_changes(cs)

    Enum.reduce(
      [
        {:max_position, c.max_position > c.min_position, "must exceed minimum position"},
        {:home_backoff, c.home_backoff < c.home_steps, "must be less than home sweep"},
        {:home_speed, c.home_speed <= c.max_speed, "must not exceed maximum speed"},
        {:home_position, c.home_position >= c.min_position and c.home_position <= c.max_position,
         "must be inside soft limits"}
      ],
      cs,
      fn {field, valid, message}, acc ->
        if valid, do: acc, else: add_error(acc, field, message)
      end
    )
  end

  defp clear_commissioning(%Ecto.Changeset{data: %{commissioned: true}} = cs) do
    if motion_changed?(cs), do: put_change(cs, :commissioned, false), else: cs
  end

  defp clear_commissioning(cs), do: cs

  defp validate_startup(cs) do
    axis = apply_changes(cs)

    if get_change(cs, :startup_reference) == :home_on_connect and not auto_home?(axis),
      do:
        add_error(
          cs,
          :startup_reference,
          "requires commissioned internal-stop axis with idle hold"
        ),
      else: cs
  end
end
