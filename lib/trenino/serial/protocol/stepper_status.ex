defmodule Trenino.Serial.Protocol.StepperStatus do
  @moduledoc "Open-loop status; known estimates do not establish physical accuracy."
  import Bitwise
  alias Trenino.Serial.Protocol.{StepperCommand, StepperConfiguration}
  @type t :: %__MODULE__{}
  defstruct [
    :operation,
    :axis,
    :request_id,
    :result,
    :state,
    :configured,
    :known,
    :energized,
    :reference_kind,
    :fault,
    :position,
    :target,
    :phase,
    :max_axes,
    :drivers,
    :modes,
    :homing
  ]

  @results [
    :ok,
    :invalid_value,
    :bad_axis,
    :unsupported,
    :resource_conflict,
    :unconfigured,
    :unreferenced,
    :outside_limits,
    :busy,
    :io_error
  ]
  @states [:disabled, :idle, :moving, :homing, :fault]
  @faults [:none, :driver_i2c, :home_timeout, :host_lost]
  @references [:unknown, :assumed_stop, :host_assigned]
  def decode_body(
        <<1, op, axis, id::little-16, result, state, flags, fault, position::little-signed-32,
          target::little-signed-32, phase, axes, drivers, modes, homing>>
      )
      when op <= 10 and axis in [0, 1, 255] and result <= 9 and state <= 4 and fault <= 3 and
             (flags &&& 24) != 24 do
    {:ok,
     %__MODULE__{
       operation: StepperCommand.operation(op),
       axis: axis,
       request_id: id,
       result: Enum.at(@results, result),
       state: Enum.at(@states, state),
       configured: (flags &&& 1) != 0,
       known: (flags &&& 2) != 0,
       energized: (flags &&& 4) != 0,
       reference_kind: Enum.at(@references, flags >>> 3 &&& 3),
       fault: Enum.at(@faults, fault),
       position: position,
       target: target,
       phase: phase,
       max_axes: axes,
       drivers: drivers,
       modes: modes,
       homing: homing
     }}
  end

  def decode_body(_), do: {:error, :invalid_stepper_status}

  @spec supports?(t(), StepperConfiguration.t()) :: boolean()
  def supports?(%__MODULE__{} = s, %StepperConfiguration{} = c) do
    bit = %{x27_six_state: 1, full_step: 2, half_step: 4}[c.mode]

    s.max_axes >= 2 and (s.drivers &&& 1) != 0 and bit != nil and (s.modes &&& bit) != 0 and
      (c.reference_strategy == :host_reference or (s.homing &&& 1) != 0)
  end
end
