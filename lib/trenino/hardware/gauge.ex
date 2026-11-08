defmodule Trenino.Hardware.Gauge do
  @moduledoc """
  An X27 gauge stepper driven by the device (firmware >= 3.3.0, `Configure` module type 7).

  `pins` always has four entries; 255 marks an unused slot:

    * `:vid6606` - `[STEP, DIR, RESET_N or 255, 255]`, one channel of a VID6606 (or
      AX1201728SG / STI6606Z). 1/12 degree per step: 315 degrees is 3780 steps.
    * `:direct` - the board pins wired to X27 contacts 1, 2, 3, 4. 1/3 degree per step:
      315 degrees is 945 steps. AVR boards only; the firmware rejects it on Due and ESP32.

  The first pin is the gauge's identity on the wire (`SetGaugePosition`, `ZeroGauge`).
  Rules that involve other gauges (four per device, pin clashes) live in
  `Trenino.Hardware`, which sees the whole device.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Hardware.{Device, DialCalibration}

  @unused 255
  @max_speed %{vid6606: 5000, direct: 1800}
  @defaults %{
    vid6606: %{travel: 3780, max_speed: 5000, acceleration: 50_000},
    direct: %{travel: 945, max_speed: 1800, acceleration: 1500}
  }

  @type driver :: :vid6606 | :direct

  @type t :: %__MODULE__{
          id: integer() | nil,
          device_id: integer() | nil,
          name: String.t() | nil,
          driver: driver(),
          pins: [non_neg_integer()],
          travel: pos_integer(),
          max_speed: pos_integer(),
          acceleration: pos_integer(),
          reverse: boolean(),
          device: Device.t() | Ecto.Association.NotLoaded.t(),
          dial_calibration: DialCalibration.t() | nil | Ecto.Association.NotLoaded.t()
        }

  schema "hardware_gauges" do
    belongs_to :device, Device
    has_one :dial_calibration, DialCalibration
    field :name, :string
    field :driver, Ecto.Enum, values: [:vid6606, :direct], default: :vid6606
    field :pins, {:array, :integer}
    field :travel, :integer, default: 3780
    field :max_speed, :integer, default: 5000
    field :acceleration, :integer, default: 50_000
    field :reverse, :boolean, default: false
    timestamps(type: :utc_datetime)
  end

  @doc "The value that marks an unused pin slot."
  @spec unused_pin() :: 255
  def unused_pin, do: @unused

  @doc "Starting travel, speed and acceleration for a driver (tune on the real gauge)."
  @spec defaults(driver()) :: %{
          travel: pos_integer(),
          max_speed: pos_integer(),
          acceleration: pos_integer()
        }
  def defaults(driver) when is_map_key(@defaults, driver), do: Map.fetch!(@defaults, driver)

  @doc "Highest `max_speed` the firmware accepts for a driver, in steps per second."
  @spec max_speed_limit(driver()) :: pos_integer()
  def max_speed_limit(driver) when is_map_key(@max_speed, driver),
    do: Map.fetch!(@max_speed, driver)

  @doc "The pin that addresses this gauge on the wire."
  @spec wire_pin(t()) :: non_neg_integer()
  def wire_pin(%__MODULE__{pins: [pin | _]}), do: pin

  @doc """
  Pins this gauge drives on its own: STEP and DIR, or the four coils. Another gauge may
  not use any of them.
  """
  @spec own_pins(t()) :: [non_neg_integer()]
  def own_pins(%__MODULE__{driver: :vid6606, pins: [step, dir | _]}), do: [step, dir]
  def own_pins(%__MODULE__{driver: :direct, pins: pins}), do: pins

  @doc "The VID6606 RESET_N pin, or nil. Gauges on one chip share it."
  @spec reset_pin(t()) :: non_neg_integer() | nil
  def reset_pin(%__MODULE__{driver: :vid6606, pins: [_, _, reset, _]}) when reset != @unused,
    do: reset

  def reset_pin(%__MODULE__{}), do: nil

  @doc "Every board pin this gauge uses."
  @spec used_pins(t()) :: [non_neg_integer()]
  def used_pins(%__MODULE__{} = gauge),
    do: Enum.reject([reset_pin(gauge) | own_pins(gauge)], &is_nil/1)

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = gauge, attrs) do
    gauge
    |> cast(attrs, [:name, :driver, :pins, :travel, :max_speed, :acceleration, :reverse])
    |> validate_required([:name, :device_id, :driver, :pins, :travel, :max_speed, :acceleration])
    |> validate_length(:name, max: 100)
    |> validate_number(:travel, greater_than_or_equal_to: 1, less_than_or_equal_to: 4000)
    |> validate_number(:acceleration, greater_than_or_equal_to: 1, less_than_or_equal_to: 60_000)
    |> validate_max_speed()
    |> validate_pins()
    |> foreign_key_constraint(:device_id)
  end

  defp validate_max_speed(cs) do
    limit = max_speed_limit(get_field(cs, :driver) || :vid6606)

    validate_number(cs, :max_speed,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: limit,
      message: "must be between 1 and #{limit} steps/s for this driver"
    )
  end

  defp validate_pins(cs) do
    case {get_field(cs, :driver), get_field(cs, :pins)} do
      {_, nil} -> cs
      {_, pins} when length(pins) != 4 -> add_error(cs, :pins, "must have four entries")
      {:vid6606, [step, dir, reset, @unused]} -> check_pins(cs, [step, dir], [reset])
      {:vid6606, _} -> add_error(cs, :pins, "VID6606 uses STEP, DIR and an optional RESET_N")
      {:direct, pins} -> check_pins(cs, pins, [])
      _ -> cs
    end
  end

  # `required` pins must be real board pins; `optional` ones may be 255 (unused).
  defp check_pins(cs, required, optional) do
    used = required ++ Enum.reject(optional, &(&1 == @unused))

    cond do
      Enum.any?(required, &(is_nil(&1) or &1 == @unused)) ->
        add_error(cs, :pins, "are missing a required pin")

      not Enum.all?(required ++ optional, &(is_integer(&1) and &1 in 0..@unused)) ->
        add_error(cs, :pins, "must be pin numbers from 0 to 254")

      length(Enum.uniq(used)) != length(used) ->
        add_error(cs, :pins, "must all be different")

      true ->
        cs
    end
  end
end
