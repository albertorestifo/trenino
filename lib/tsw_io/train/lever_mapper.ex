defmodule TswIo.Train.LeverMapper do
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

  alias TswIo.Train.{LeverConfig, Notch}

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
        calculate_sim_input(notch, effective_value)
    end
  end

  def map_input(%LeverConfig{}, input_value) when is_float(input_value) do
    # Out-of-range values (below 0.0 or above 1.0) - return error
    {:error, :no_notch}
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
  Calculate the simulator InputValue for a notch given a hardware input value.

  For gate notches, returns the center of the sim_input range.
  For linear notches, interpolates within the sim_input range.
  """
  @spec calculate_sim_input(Notch.t(), float()) :: {:ok, float()} | {:error, atom()}
  def calculate_sim_input(
        %Notch{type: :gate, sim_input_min: sim_min, sim_input_max: sim_max},
        _input_value
      )
      when is_float(sim_min) and is_float(sim_max) do
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
        input_value
      )
      when is_float(input_min) and is_float(input_max) and
             is_float(sim_min) and is_float(sim_max) do
    # Calculate position within the notch's hardware input range (0.0 to 1.0)
    input_range = input_max - input_min
    position = (input_value - input_min) / input_range

    # Interpolate within the notch's simulator input range
    sim_range = sim_max - sim_min
    sim_value = sim_min + position * sim_range

    # Round to 2 decimal places
    {:ok, Float.round(sim_value, 2)}
  end

  def calculate_sim_input(%Notch{sim_input_min: nil}, _input_value) do
    {:error, :no_sim_input_range}
  end

  def calculate_sim_input(%Notch{sim_input_max: nil}, _input_value) do
    {:error, :no_sim_input_range}
  end

  def calculate_sim_input(%Notch{input_min: nil}, _input_value) do
    {:error, :unmapped_notch}
  end

  def calculate_sim_input(%Notch{input_max: nil}, _input_value) do
    {:error, :unmapped_notch}
  end

  def calculate_sim_input(%Notch{}, _input_value) do
    {:error, :unmapped_notch}
  end

  # Legacy function for backwards compatibility
  @doc false
  @spec calculate_value(Notch.t(), float()) :: {:ok, float()} | {:error, :unmapped_notch}
  def calculate_value(notch, input_value), do: calculate_sim_input(notch, input_value)
end
