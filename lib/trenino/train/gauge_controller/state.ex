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
    # binding id => %{target, at}: the last target sent, so an unchanged sample is not
    # resent every poll.
    sent: %{},
    # device id => {{:ok, port} | {:error, reason}, checked_at}: where gauge commands go.
    links: %{},
    # gauge id => %{ref: monitor ref | nil, until: monotonic ms | nil}: manual control.
    manual: %{},
    cleaning: false,
    retry_after: %{},
    id_base: 4000,
    cleanup_attempts: 0,
    last_error: nil,
    endpoint_errors: %{}
  ]

  @type t :: %__MODULE__{}
end
