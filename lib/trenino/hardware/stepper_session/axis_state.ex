defmodule Trenino.Hardware.StepperSession.AxisState do
  @moduledoc "Volatile state for a configured axis and its reference epoch."
  defstruct [
    :config,
    :status,
    :updated_at,
    :pending,
    :desired_target,
    :last_target,
    :error,
    :release_waiter,
    # Lease info for status reports; filled in by StepperManager, never by the session.
    :lease,
    ready: false,
    reference_accepted: false,
    reference_poll: nil,
    paused: false
  ]

  @type t :: %__MODULE__{}
end
