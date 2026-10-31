defmodule Trenino.Hardware.GaugeWizard.Observation do
  @moduledoc "Normalised device status for one axis, built from a `StepperManager.snapshot/1`."
  defstruct lifecycle: :disconnected,
            ready: false,
            state: nil,
            known: false,
            position: nil,
            fault: :none,
            pending?: false,
            age_ms: nil,
            lease_held?: false,
            config_applied?: false,
            homed?: false

  @type t :: %__MODULE__{}
end
