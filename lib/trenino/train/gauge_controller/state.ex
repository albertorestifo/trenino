defmodule Trenino.Train.GaugeController.State do
  @moduledoc "Active gauge bindings, their latest samples and volatile gauge diagnostics."

  @type t :: %__MODULE__{
          train: Trenino.Train.Train.t() | nil,
          timer: reference() | nil,
          generation: non_neg_integer(),
          connected: boolean(),
          bindings: %{integer() => Trenino.Train.GaugeBinding.t()},
          status: %{integer() => map()},
          sent: %{integer() => %{target: integer(), at: integer()}},
          links: %{integer() => {{:ok, String.t()} | {:error, term()}, integer()}},
          manual: %{integer() => %{ref: reference() | nil, until: integer() | nil}},
          last_error: term()
        }

  defstruct [
    :train,
    :timer,
    # Tags the tick timer, so a tick from before a train change is ignored.
    generation: 0,
    connected: false,
    bindings: %{},
    status: %{},
    # binding id => %{target, at}: the last target sent, so an unchanged sample is not
    # resent every poll.
    sent: %{},
    # device id => {{:ok, port} | {:error, reason}, checked_at}: where gauge commands go.
    links: %{},
    # gauge id => %{ref: monitor ref | nil, until: monotonic ms | nil}: manual control.
    manual: %{},
    last_error: nil
  ]
end
