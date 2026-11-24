defmodule Trenino.Hardware.AngleSensor do
  @moduledoc """
  Magnetic angle sensors an analog input can be read by over I2C, instead of an
  Arduino analog pin.

  Each chip has a fixed list of addresses, and each address has a fixed report pin:
  the `pin` the device puts in that sensor's `InputValue` messages. Pins 240-247 are
  kept for these; they can't clash with physical pins (0-127) or matrix buttons
  (128-191). Because the pin follows from the address, the inputs table's
  `(device_id, pin)` unique index also keeps two sensors off the same address.

  A sensor reports one full turn as `0..max_raw`, so its calibration is circular
  (see `Trenino.Hardware.Calibration.Calculator`).
  """

  @enforce_keys [:id, :name, :max_raw, :firmware, :addresses]
  defstruct [:id, :name, :max_raw, :firmware, :addresses]

  @typedoc "One address the chip can answer at: report pin and the label shown in the UI."
  @type address :: %{address: 0..127, pin: 240..247, label: String.t()}

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          max_raw: pos_integer(),
          firmware: String.t(),
          addresses: [address()]
        }

  # Built in a function: the struct can't be used in this module's own attributes.
  defp sensors do
    %{
      mt6701: %__MODULE__{
        id: :mt6701,
        name: "MT6701",
        max_raw: 16_383,
        firmware: "3.4.0",
        addresses: [
          %{address: 0x06, pin: 240, label: "0x06 (first board, factory setting)"},
          %{address: 0x46, pin: 241, label: "0x46 (second board)"}
        ]
      }
    }
  end

  @doc "Sensor ids that are angle sensors."
  @spec ids() :: [atom()]
  def ids, do: Map.keys(sensors())

  @doc "Lowest firmware version that reads any angle sensor."
  @spec firmware_version() :: String.t()
  def firmware_version do
    sensors()
    |> Map.values()
    |> Enum.map(& &1.firmware)
    |> Enum.min_by(&Version.parse!/1, Version)
  end

  @doc "The spec for a sensor id, or `nil` for the ADC and unknown values."
  @spec get(atom() | String.t() | nil) :: t() | nil
  def get(id) when is_atom(id), do: Map.get(sensors(), id)

  def get(id) when is_binary(id) do
    Enum.find_value(sensors(), fn {key, spec} -> if Atom.to_string(key) == id, do: spec end)
  end

  @doc "True for a sensor id read over I2C as an angle."
  @spec angle_sensor?(atom() | String.t() | nil) :: boolean()
  def angle_sensor?(id), do: get(id) != nil

  @doc "The I2C addresses a sensor answers at."
  @spec addresses(t()) :: [0..127]
  def addresses(%__MODULE__{addresses: addresses}), do: Enum.map(addresses, & &1.address)

  @doc "The report pin for an address, or `nil` when the chip can't use that address."
  @spec report_pin(t(), integer() | nil) :: integer() | nil
  def report_pin(%__MODULE__{addresses: addresses}, address) do
    Enum.find_value(addresses, fn a -> if a.address == address, do: a.pin end)
  end

  @doc "Format an address the way the UI shows it: `0x06`."
  @spec format_address(integer()) :: String.t()
  def format_address(address) when is_integer(address) do
    "0x" <> String.pad_leading(Integer.to_string(address, 16), 2, "0")
  end

  @doc "Raw counts in one full turn."
  @spec counts_per_turn(t()) :: pos_integer()
  def counts_per_turn(%__MODULE__{max_raw: max_raw}), do: max_raw + 1

  @doc "Degrees for a raw reading, rounded to 2 places."
  @spec degrees(t(), integer()) :: float()
  def degrees(%__MODULE__{} = spec, raw) when is_integer(raw) do
    Float.round(raw * 360 / counts_per_turn(spec), 2)
  end

  @doc "A raw reading as an angle for the UI: `\"180.00°\"`."
  @spec format_degrees(t(), integer()) :: String.t()
  def format_degrees(%__MODULE__{} = spec, raw) do
    :erlang.float_to_binary(degrees(spec, raw), decimals: 2) <> "°"
  end

  @doc "Raw counts for an angle in degrees, rounded."
  @spec counts(t(), number()) :: non_neg_integer()
  def counts(%__MODULE__{} = spec, degrees), do: round(degrees * counts_per_turn(spec) / 360)

  @doc """
  The shortest signed step from `from` to `to` on a circle of `n` counts, in
  `-(n/2)..(n/2)`. 16383 -> 1 on a 16384-count circle is `+2`.
  """
  @spec shortest_delta(integer(), integer(), pos_integer()) :: integer()
  def shortest_delta(from, to, n) do
    d = Integer.mod(to - from, n)

    cond do
      2 * d < n -> d
      2 * d > n -> d - n
      # Exactly half a turn: pick the sign so that a step and its way back cancel.
      to > from -> d
      true -> -d
    end
  end
end
