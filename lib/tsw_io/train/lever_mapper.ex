defmodule TswIo.Train.LeverMapper do
  @moduledoc """
  Maps calibrated hardware input values to simulator lever values.

  This module handles the conversion from normalized input values (0.0-1.0)
  to appropriate simulator values based on the lever's notch configuration.

  ## Data Flow

  The complete pipeline for lever input processing:

  1. **Hardware**: Raw ADC value (e.g., 0-1023 from potentiometer)
  2. **Calibration**: `Hardware.Calibration.Calculator.normalize/2` converts to
     calibrated integer (0 to total_travel, e.g., 0-800)
  3. **Normalization**: `LeverController` divides by total_travel to get 0.0-1.0 float
  4. **Mapping** (this module): Converts 0.0-1.0 to simulator value using notch configuration
  5. **Simulator**: Final value sent to simulator (can be any float, including negative)

  ## Mapping Algorithm

  1. Receive normalized input value (0.0-1.0) representing physical lever position
  2. Find matching notch based on input_min/input_max ranges
  3. Convert to simulator value:
     - **Gate notch**: Return the fixed `value` (e.g., -1.0, 0.0, 1.0 for reverser)
     - **Linear notch**: Interpolate between `min_value` and `max_value`

  ## Example: Reverser Configuration

  Physical lever position (normalized 0.0-1.0) to simulator value (-1.0 to 1.0):

      notches = [
        %Notch{
          type: :linear,
          min_value: -1.0,   # Simulator: full reverse
          max_value: 1.0,    # Simulator: full forward
          input_min: 0.0,    # Physical: lever all the way back
          input_max: 1.0     # Physical: lever all the way forward
        }
      ]

  When physical lever is at 25% position (input 0.25):
  - Position within notch: (0.25 - 0.0) / (1.0 - 0.0) = 0.25
  - Simulator value: -1.0 + (0.25 * 2.0) = -0.5

  ## Interactive Calibration Workflow

  When binding a physical input to a lever via the UI:

  1. User moves physical lever to desired position for notch boundary
  2. System samples current normalized input value (0.0-1.0)
  3. User assigns this position as `input_min` or `input_max` for the notch
  4. Repeat for all notch boundaries
  5. System validates that notches cover the full 0.0-1.0 range (or partial range with dead zones)

  The normalization abstraction (0.0-1.0) makes configurations portable across
  different hardware inputs with varying physical characteristics.
  """

  alias TswIo.Train.{LeverConfig, Notch}

  @type map_result ::
          {:ok, float()}
          | {:error, :no_notch}
          | {:error, :unmapped_notch}

  @doc """
  Map a normalized input value to a simulator value for a lever.

  Takes a calibrated input value (0.0-1.0) and returns the appropriate
  simulator value based on the lever's notch configuration.

  ## Parameters

    * `lever_config` - The lever config with preloaded notches
    * `input_value` - Normalized input value from 0.0 to 1.0

  ## Returns

    * `{:ok, value}` - The simulator value to send
    * `{:error, :no_notch}` - No notch matches the input value
    * `{:error, :unmapped_notch}` - Notch found but has no input range mapping

  ## Examples

      iex> LeverMapper.map_input(lever_config, 0.5)
      {:ok, 0.75}

  """
  @spec map_input(LeverConfig.t(), float()) :: map_result()
  def map_input(%LeverConfig{notches: notches}, input_value)
      when is_float(input_value) and input_value >= 0.0 and input_value <= 1.0 do
    # Find the notch that contains this input value
    case find_notch(notches, input_value) do
      nil ->
        {:error, :no_notch}

      notch ->
        calculate_value(notch, input_value)
    end
  end

  def map_input(%LeverConfig{}, input_value) when is_float(input_value) do
    # Clamp out-of-range values
    clamped = max(0.0, min(1.0, input_value))
    map_input_clamped(clamped)
  end

  defp map_input_clamped(_value), do: {:error, :no_notch}

  @doc """
  Find which notch contains a given input value.

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
  Calculate the simulator value for a notch given an input value.

  For gate notches, returns the fixed value.
  For linear notches, interpolates between min_value and max_value.
  """
  @spec calculate_value(Notch.t(), float()) :: {:ok, float()} | {:error, :unmapped_notch}
  def calculate_value(%Notch{type: :gate, value: value}, _input_value) when is_float(value) do
    {:ok, value}
  end

  def calculate_value(
        %Notch{
          type: :linear,
          min_value: min_val,
          max_value: max_val,
          input_min: input_min,
          input_max: input_max
        },
        input_value
      )
      when is_float(min_val) and is_float(max_val) and
             is_float(input_min) and is_float(input_max) do
    # Calculate position within the notch's input range (0.0 to 1.0)
    input_range = input_max - input_min
    position = (input_value - input_min) / input_range

    # Interpolate within the notch's output range
    output_range = max_val - min_val
    output_value = min_val + position * output_range

    # Round to 2 decimal places
    {:ok, Float.round(output_value, 2)}
  end

  def calculate_value(%Notch{}, _input_value) do
    {:error, :unmapped_notch}
  end
end
