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
    cleaning: false,
    retry_after: %{},
    id_base: 4000,
    cleanup_attempts: 0,
    last_error: nil,
    endpoint_errors: %{}
  ]

  @type t :: %__MODULE__{}
end
