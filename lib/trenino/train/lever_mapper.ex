defmodule Trenino.Train.LeverMapper do
  @moduledoc """
  Maps calibrated hardware input values to simulator lever InputValue.

  This module handles the conversion from normalized hardware input values (0.0-1.0)
  to the simulator's InputValue (also 0.0-1.0) based on the lever's notch configuration.

  ## Data Flow

  The complete pipeline for lever input processing:

  1. **Hardware**: Raw ADC value (e.g., 0-1023 from potentiometer)
  2. **Calibration**: `Hardware.Calibration.Calculator.normalize/2` converts to
     calibrated integer (0 to total_travel, e.g., 0-800)
  3. **Normalization**: `LeverController` divides by total_travel to get 0.0-1.0 float
  4. **Mapping** (this module): Converts hardware 0.0-1.0 to simulator InputValue 0.0-1.0
  5. **Simulator**: InputValue is sent to simulator, which produces output values

  ## Notch Fields

  Each notch has two input ranges:
  - `input_min/input_max`: Hardware position range (where physical lever is)
  - `sim_input_min/sim_input_max`: Simulator InputValue range (what to send)

  ## Mapping Algorithm

  1. Receive normalized hardware input value (0.0-1.0)
  2. Find matching notch based on input_min/input_max (hardware position)
  3. Calculate position within the notch's hardware range
  4. Map to simulator InputValue using sim_input_min/sim_input_max:
     - **Gate notch**: Return center of sim_input range
     - **Linear notch**: Interpolate within sim_input range

  ## Example: MasterController Braking

      %Notch{
        type: :linear,
        input_min: 0.1,        # Hardware: 10% of lever travel
        input_max: 0.4,        # Hardware: 40% of lever travel
        sim_input_min: 0.05,   # Simulator: sends InputValue 0.05
        sim_input_max: 0.45,   # Simulator: sends InputValue 0.45
        min_value: -10.0,      # Output: full braking (informational)
        max_value: -0.91       # Output: light braking (informational)
      }

  When physical lever is at 25% (input 0.25):
  - Position within notch: (0.25 - 0.1) / (0.4 - 0.1) = 0.5
  - Simulator InputValue: 0.05 + (0.5 * (0.45 - 0.05)) = 0.25
  """

  alias Trenino.Train.{LeverConfig, Notch}

  @type map_result ::
          {:ok, float()}
          | {:error, :no_notch}
          | {:error, :unmapped_notch}
          | {:error, :no_sim_input_range}
          | {:error, :zero_width_notch}

  @doc """
  Map a normalized hardware input value to a simulator InputValue.

  Takes a calibrated hardware input value (0.0-1.0) and returns the appropriate
  simulator InputValue (0.0-1.0) based on the lever's notch configuration.

  ## Parameters

    * `lever_config` - The lever config with preloaded notches
    * `input_value` - Normalized hardware input value from 0.0 to 1.0

  ## Returns

    * `{:ok, sim_input}` - The simulator InputValue to send (0.0-1.0)
    * `{:error, :no_notch}` - No notch matches the hardware input value
    * `{:error, :unmapped_notch}` - Notch found but has no hardware input range
    * `{:error, :no_sim_input_range}` - Notch has no simulator input range

  ## Examples

      iex> LeverMapper.map_input(lever_config, 0.25)
      {:ok, 0.25}

  """
  @spec map_input(LeverConfig.t(), float()) :: map_result()
  def map_input(%LeverConfig{} = lever_config, input_value) when is_float(input_value) do
    case resolve_input(lever_config, input_value) do
      {:ok, _notch, sim_input} -> {:ok, sim_input}
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Like `map_input/2`, but also returns the notch the input resolved to.

  This is the single implementation of the hardware -> simulator mapping;
  `map_input/2` delegates to it. Callers that need to know *which* notch a
  hardware position lands in (e.g. the notch mapping wizard preview) use this
  so their answer can never diverge from the runtime mapping.
  """
  @spec resolve_input(LeverConfig.t(), float()) ::
          {:ok, Notch.t(), float()}
          | {:error, :no_notch | :unmapped_notch | :no_sim_input_range | :zero_width_notch}
  def resolve_input(%LeverConfig{notches: notches, inverted: inverted}, input_value)
      when is_float(input_value) and input_value >= 0.0 and input_value <= 1.0 do
    # Apply inversion if configured (hardware direction opposite to simulator)
    effective_value = if inverted, do: Float.round(1.0 - input_value, 2), else: input_value

    # Find the notch that contains this hardware input value
    case find_notch(notches, effective_value) do
      nil ->
        {:error, :no_notch}

      notch ->
        # Stored input ranges are in effective space and sim_input ranges are always
        # min <= max, so when the layout is descending (sim falls as effective input
        # rises) the interpolation inside a linear notch has to run backwards too.
        # This is independent of `inverted`, which the `1 - x` step above already
        # consumed. The wizard picks `inverted` with this same rule
        # (`descending?/1` on the raw captures), so layouts it saves are
        # ascending; hand-edited or MCP-written layouts may be descending.
        # Gates ignore it, so only pay for the layout scan on linear notches.
        invert_position = notch.type == :linear and reversed_layout?(notches)

        case calculate_sim_input(notch, effective_value, invert_position) do
          {:ok, sim_input} -> {:ok, notch, sim_input}
          {:error, _reason} = error -> error
        end
    end
  end

  def resolve_input(%LeverConfig{}, input_value) when is_float(input_value) do
    # Out-of-range values (below 0.0 or above 1.0) - return error
    {:error, :no_notch}
  end

  # Gates narrower than @min_gate_catch_width are matched inclusively, padded by
  # @gate_catch_pad on each side. Hardware resolution is 0.01, and the wizard
  # accepts single-point gate captures that Notch.changeset rounds to zero width;
  # under half-open matching such a detent could never be reached. Wider gates
  # are already reachable and keep half-open matching, so existing layouts with
  # shared boundaries resolve exactly as before.
  @min_gate_catch_width 0.02
  @gate_catch_pad 0.01

  @doc """
  Find which notch contains a given hardware input value.

  Matching rules, in priority order:

    1. Gates narrower than #{@min_gate_catch_width} match inclusively within
       `[input_min - #{@gate_catch_pad}, input_max + #{@gate_catch_pad}]` (a
       zero-width gate at 0.5 catches 0.49..0.51). A detent wins over an
       overlapping linear notch; between narrow gates the nearest centre wins.
    2. Any other mapped notch matches the half-open range `[input_min, input_max)`,
       gates before linear notches.
    3. A notch whose `input_max` is exactly 1.0 also matches 1.0.

  Returns nil if no notch matches.
  """
  @spec find_notch([Notch.t()], float()) :: Notch.t() | nil
  def find_notch(notches, input_value) do
    mapped = Enum.filter(notches, &(&1.input_min != nil and &1.input_max != nil))

    in_range? = &(input_value >= &1.input_min and input_value < &1.input_max)

    find_narrow_gate(mapped, input_value) ||
      Enum.find(mapped, &(&1.type == :gate and in_range?.(&1))) ||
      Enum.find(mapped, &(&1.type != :gate and in_range?.(&1))) ||
      Enum.find(mapped, fn notch ->
        input_value == notch.input_max and notch.input_max == 1.0
      end)
  end

  # Among narrow gates whose padded range contains the value, the one whose
  # centre is closest wins.
  defp find_narrow_gate(mapped, input_value) do
    mapped
    |> Enum.filter(&(narrow_gate?(&1) and in_catch_range?(&1, input_value)))
    |> case do
      [] -> nil
      gates -> Enum.min_by(gates, &abs(input_value - (&1.input_min + &1.input_max) / 2))
    end
  end

  # Widths and bounds are rounded so they compare exactly against 2-decimal
  # hardware inputs (0.12 - 0.1 is not exactly 0.02 in floating point)
  defp narrow_gate?(%Notch{type: :gate, input_min: min, input_max: max}),
    do: Float.round((max - min) / 1, 2) < @min_gate_catch_width

  defp narrow_gate?(%Notch{}), do: false

  defp in_catch_range?(%Notch{input_min: min, input_max: max}, input_value) do
    input_value >= Float.round(min - @gate_catch_pad, 2) and
      input_value <= Float.round(max + @gate_catch_pad, 2)
  end

  @typedoc "A notch's hardware range and simulator input range."
  @type direction_entry ::
          {hw_min :: number(), hw_max :: number(), sim_min :: number(), sim_max :: number()}

  @doc """
  Whether a layout is descending: the notch whose hardware range centre is
  lowest has a higher sim_input centre than the notch whose hardware centre is
  highest.

  This is the single direction rule shared by the notch mapping wizard (fed raw
  captured ranges, to decide `inverted`) and the runtime mapper (fed stored
  effective ranges, to decide whether linear interpolation runs backwards).
  Both sides of each entry must be in the same space. Ties on the hardware
  centre resolve to the first entry. Returns false for fewer than 2 entries.
  """
  @spec descending?([direction_entry()]) :: boolean()
  def descending?(entries) when length(entries) < 2, do: false

  def descending?(entries) when is_list(entries) do
    hw_center = fn {hw_min, hw_max, _, _} -> (hw_min + hw_max) / 2 end
    sim_center = fn {_, _, sim_min, sim_max} -> (sim_min + sim_max) / 2 end

    first = Enum.min_by(entries, hw_center)
    last = Enum.max_by(entries, hw_center)

    sim_center.(first) > sim_center.(last)
  end

  @doc """
  Detect if a notch layout is "reversed" - where higher input values correspond
  to lower sim values.

  Uses `descending?/1` on the notches that have both a hardware input range and
  a sim_input range. This is common in MasterController-style levers where
  Emergency is at one physical extreme and Power is at the other.

  ## Examples

  Forward layout (standard): input 0→1 maps to sim 0→1
      Braking notch: input 0.0-0.45, sim 0.0-0.45
      Power notch:   input 0.55-1.0, sim 0.55-1.0

  Reversed layout (M9-A style): input 0→1 maps to sim 1→0
      Power notch:     input 0.0-0.45,  sim 0.56-1.0
      Emergency notch: input 0.99-1.0,  sim 0.0-0.04
  """
  @spec reversed_layout?([Notch.t()]) :: boolean()
  def reversed_layout?(notches) do
    notches
    |> Enum.filter(fn n ->
      n.input_min != nil and n.input_max != nil and
        n.sim_input_min != nil and n.sim_input_max != nil
    end)
    |> Enum.map(&{&1.input_min, &1.input_max, &1.sim_input_min, &1.sim_input_max})
    |> descending?()
  end

  @doc """
  Calculate the simulator InputValue for a notch given a hardware input value.

  For gate notches, returns the center of the sim_input range.
  For linear notches, interpolates within the sim_input range.

  When `invert_position` is true, linear interpolation is reversed so that lower
  effective input values map to higher sim_input values. This is needed for
  descending (reversed) notch layouts.
  """
  @spec calculate_sim_input(Notch.t(), float(), boolean()) :: {:ok, float()} | {:error, atom()}
  def calculate_sim_input(notch, input_value, invert_position \\ false)

  def calculate_sim_input(
        %Notch{type: :gate, sim_input_min: sim_min, sim_input_max: sim_max},
        _input_value,
        _invert_position
      )
      when is_number(sim_min) and is_number(sim_max) do
    # For gates, return center of the simulator input range
    center = (sim_min + sim_max) / 2
    {:ok, Float.round(center, 2)}
  end

  # A linear notch captured with a tiny sweep can round to zero width when saved;
  # there is no position to interpolate, so treat it as unmapped instead of dividing by zero
  def calculate_sim_input(
        %Notch{type: :linear, input_min: input_min, input_max: input_max},
        _input_value,
        _invert_position
      )
      when is_number(input_min) and is_number(input_max) and input_max <= input_min do
    {:error, :zero_width_notch}
  end

  def calculate_sim_input(
        %Notch{
          type: :linear,
          input_min: input_min,
          input_max: input_max,
          sim_input_min: sim_min,
          sim_input_max: sim_max
        },
        input_value,
        invert_position
      )
      when is_number(input_min) and is_number(input_max) and
             is_number(sim_min) and is_number(sim_max) do
    # Calculate position within the notch's hardware input range (0.0 to 1.0)
    input_range = input_max - input_min
    position = (input_value - input_min) / input_range

    # For descending layouts, invert the position so that lower effective
    # values map to higher sim values
    effective_position = if invert_position, do: 1.0 - position, else: position

    # Interpolate within the notch's simulator input range
    sim_range = sim_max - sim_min
    sim_value = sim_min + effective_position * sim_range

    # Round to 2 decimal places
    {:ok, Float.round(sim_value, 2)}
  end

  def calculate_sim_input(%Notch{sim_input_min: nil}, _input_value, _invert_position) do
    {:error, :no_sim_input_range}
  end

  def calculate_sim_input(%Notch{sim_input_max: nil}, _input_value, _invert_position) do
    {:error, :no_sim_input_range}
  end

  def calculate_sim_input(%Notch{input_min: nil}, _input_value, _invert_position) do
    {:error, :unmapped_notch}
  end

  def calculate_sim_input(%Notch{input_max: nil}, _input_value, _invert_position) do
    {:error, :unmapped_notch}
  end

  def calculate_sim_input(%Notch{}, _input_value, _invert_position) do
    {:error, :unmapped_notch}
  end

  # Legacy function for backwards compatibility
  @doc false
  @spec calculate_value(Notch.t(), float()) :: {:ok, float()} | {:error, :unmapped_notch}
  def calculate_value(notch, input_value), do: calculate_sim_input(notch, input_value)
end
