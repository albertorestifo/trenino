defmodule Trenino.Hardware.StepperSession.State do
  @moduledoc "Session snapshot. Axis entries use database IDs; positions are volatile estimates."
  defstruct [
    :port,
    :generation,
    :device_id,
    :send_fun,
    :capabilities,
    :global_pending,
    :deployment_waiter,
    :deployment_token,
    :error,
    :timer_epoch,
    axes: %{},
    queue: [],
    lifecycle: :probing,
    next_id: 1,
    ack_timeout: 250,
    idle_poll: 1000,
    moving_poll: 250,
    watchdog_interval: 250
  ]

  @type t :: %__MODULE__{}
end
