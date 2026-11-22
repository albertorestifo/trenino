defmodule Trenino.Simulator.Control do
  @moduledoc """
  A cab control as reported by a simulator backend that knows its controls
  (SimRail). Backends that don't (TSW) discover levers by sweeping instead.

  `path` is the value the control writes. Several controls can share a path
  (one per cab) and still have different `positions`, so notch tables belong
  to the control, not to the path.
  """

  alias Trenino.Simulator.Control.Position

  @type kind :: :lever | :switch | :button | :flap | :other

  @type t :: %__MODULE__{
          id: String.t(),
          kind: kind(),
          type: String.t() | nil,
          path: String.t() | nil,
          position: integer() | nil,
          positions: [Position.t()],
          pressed_value: float() | nil,
          released_value: float() | nil,
          actions: [String.t()]
        }

  @enforce_keys [:id, :kind]
  defstruct [
    :id,
    :kind,
    :type,
    :path,
    :position,
    :pressed_value,
    :released_value,
    positions: [],
    actions: []
  ]

  defmodule Position do
    @moduledoc """
    One position of a control's notch table.

    * `value` - the simulator value written in this position.
    * `stable` - the position index the control springs back to when
      released. Equal to `index` (or nil) for positions that hold.
    * `lower`/`upper` - for smooth levers, the band of values that belongs
      to this position.
    """

    @type t :: %__MODULE__{
            index: non_neg_integer(),
            value: float() | nil,
            label: String.t() | nil,
            stable: non_neg_integer() | nil,
            lower: float() | nil,
            upper: float() | nil,
            smooth: boolean()
          }

    @enforce_keys [:index]
    defstruct [:index, :value, :label, :stable, :lower, :upper, smooth: false]
  end

  @doc "Whether the control springs back from `position` to another position."
  @spec momentary?(Position.t()) :: boolean()
  def momentary?(%Position{stable: nil}), do: false
  def momentary?(%Position{index: index, stable: stable}), do: stable != index
end
