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
  def map_input(%LeverConfig{notches: notches, inverted: inverted}, input_value)
      when is_float(input_value) and input_value >= 0.0 and input_value <= 1.0 do
    # Apply inversion if configured (hardware direction opposite to simulator)
    effective_value = if inverted, do: Float.round(1.0 - input_value, 2), else: input_value

    # Find the notch that contains this hardware input value
    case find_notch(notches, effective_value) do
      nil ->
        {:error, :no_notch}

      notch ->
        # For inverted levers with reversed notch layouts, we need to also invert
        # the position within linear notches. A "reversed" layout is when high input
        # values correspond to low sim values (e.g., emergency at input 1.0, power at input 0).
        invert_position = inverted == true and reversed_layout?(notches)
        calculate_sim_input(notch, effective_value, invert_position)
    end
  end

  def map_input(%LeverConfig{}, input_value) when is_float(input_value) do
    # Out-of-range values (below 0.0 or above 1.0) - return error
    {:error, :no_notch}
  end

  @doc """
  Map a BLDC detent index to a simulator InputValue.

  BLDC levers self-calibrate on the firmware side and report discrete detent
  indices (0, 1, 2, ...). The firmware only creates detents from gate notches,
  so detent index N corresponds to the Nth gate notch (sorted by index).

  Returns the center of that gate notch's sim_input range.

  ## Parameters

    * `lever_config` - The lever config with preloaded notches
    * `detent_index` - The detent index reported by firmware (0-based)

  ## Returns

    * `{:ok, sim_input}` - The simulator InputValue to send
    * `{:error, :no_gate_at_index}` - No gate notch exists at this detent index
    * `{:error, :no_sim_input_range}` - Gate notch has no simulator input range

  """
  @spec map_detent(LeverConfig.t(), non_neg_integer()) ::
          {:ok, float()} | {:error, :no_gate_at_index} | {:error, :no_sim_input_range}
  def map_detent(%LeverConfig{notches: notches}, detent_index)
      when is_integer(detent_index) and detent_index >= 0 do
    gate_notches =
      notches
      |> Enum.filter(&(&1.type == :gate))
      |> Enum.sort_by(& &1.index)

    case Enum.at(gate_notches, detent_index) do
      nil ->
        {:error, :no_gate_at_index}

      %Notch{sim_input_min: sim_min, sim_input_max: sim_max}
      when is_number(sim_min) and is_number(sim_max) ->
        {:ok, Float.round((sim_min + sim_max) / 2, 2)}

      %Notch{} ->
        {:error, :no_sim_input_range}
    end
  end

  @doc """
  Find which notch contains a given hardware input value.

  Returns the notch whose input_min/input_max range contains the value,
  or nil if no notch matches.
  """
  @spec find_notch([Notch.t()], float()) :: Notch.t() | nil
  def find_notch(notches, input_value) do
    Enum.find(notches, fn notch ->
      notch.input_min != nil and
        notch.input_max != nil and
        input_value >= notch.input_min and
        input_value < notch.input_max
    end)
    |> case do
      nil ->
        # Check for exact max boundary (1.0)
        Enum.find(notches, fn notch ->
          notch.input_min != nil and
            notch.input_max != nil and
            input_value == notch.input_max and
            notch.input_max == 1.0
        end)

      notch ->
        notch
    end
  end

  @doc """
  Detect if a notch layout is "reversed" - where higher input values correspond
  to lower sim values.

  A reversed layout occurs when the notch with the lowest input range has a higher
  sim_input range than the notch with the highest input range. This is common in
  MasterController-style levers where Emergency is at one physical extreme and
  Power is at the other.

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
    # Get mapped notches (those with input ranges)
    mapped =
      Enum.filter(notches, fn n ->
        n.input_min != nil and n.input_max != nil and
          n.sim_input_min != nil and n.sim_input_max != nil
      end)

    # Need at least 2 notches to determine orientation
    if length(mapped) < 2 do
      false
    else
      # Find notch with lowest input_min and highest input_max
      first_notch = Enum.min_by(mapped, & &1.input_min)
      last_notch = Enum.max_by(mapped, & &1.input_max)

      # Reversed if first notch has higher sim values than last notch
      first_notch.sim_input_min > last_notch.sim_input_max
    end
  end

  @doc """
  Calculate the simulator InputValue for a notch given a hardware input value.

  For gate notches, returns the center of the sim_input range.
  For linear notches, interpolates within the sim_input range.

  When `invert_position` is true, linear interpolation is reversed so that lower
  effective input values map to higher sim_input values. This is needed for inverted
  levers with reversed notch layouts.
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

    # For inverted levers with reversed layouts, invert the position so that
    # lower effective values (user's physical "max" position) map to higher sim values
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
