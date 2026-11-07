defmodule Trenino.Train.GaugeController.State do
  @moduledoc "Generation-tagged simulator subscriptions and volatile gauge diagnostics."
  defstruct [
    :train,
    :client,
    :task,
    :timer,
    :cleanup_job,
    generation: 0,
    bindings: %{},
    subscriptions: %{},
    status: %{},
    # binding id => %{target, at}: the last target the manager accepted, so an unchanged
    # sample is not resent every poll.
    sent: %{},
    stepper_devices: MapSet.new(),
    cleaning: false,
    retry_after: %{},
    id_base: 4000,
    cleanup_attempts: 0,
    last_error: nil,
    endpoint_errors: %{}
  ]

  @type t :: %__MODULE__{}
end
