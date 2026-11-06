defmodule Trenino.Train.Action do
  @moduledoc """
  A resolved, ready-to-run action.

  Actions are built from stored configuration (for example a selector
  position's enter or exit fields) and executed by
  `Trenino.Train.ActionExecutor`. Sequences carry their commands, so running
  an action never touches the database.
  """

  alias Trenino.Train.{SelectorPosition, Sequence}

  @type kind :: :set_value | :sequence | :keystroke

  @type command :: %{endpoint: String.t(), value: float(), delay_ms: non_neg_integer()}

  @type t :: %__MODULE__{
          kind: kind(),
          endpoint: String.t() | nil,
          value: float() | nil,
          keystroke: String.t() | nil,
          sequence_id: integer() | nil,
          commands: [command()]
        }

  @enforce_keys [:kind]
  defstruct [:kind, :endpoint, :value, :keystroke, :sequence_id, commands: []]

  @doc """
  Build the enter or exit action of a selector position.

  Sequence actions need the position's `enter_sequence` / `exit_sequence`
  preloaded with `:commands`. Returns `nil` when there is nothing to run: the
  kind is `:none`, or a sequence action has no loaded sequence.
  """
  @spec from_position(SelectorPosition.t(), :enter | :exit) :: t() | nil
  def from_position(%SelectorPosition{} = position, :enter) do
    build(
      position.enter_kind,
      position.enter_endpoint,
      position.enter_value,
      position.enter_keystroke,
      position.enter_sequence
    )
  end

  def from_position(%SelectorPosition{} = position, :exit) do
    build(
      position.exit_kind,
      position.exit_endpoint,
      position.exit_value,
      position.exit_keystroke,
      position.exit_sequence
    )
  end

  defp build(:set_value, endpoint, value, _keystroke, _sequence),
    do: %__MODULE__{kind: :set_value, endpoint: endpoint, value: value}

  defp build(:keystroke, _endpoint, _value, keystroke, _sequence),
    do: %__MODULE__{kind: :keystroke, keystroke: keystroke}

  defp build(:sequence, _endpoint, _value, _keystroke, %Sequence{commands: commands} = sequence)
       when is_list(commands) do
    %__MODULE__{
      kind: :sequence,
      sequence_id: sequence.id,
      commands: Enum.map(commands, &Map.take(&1, [:endpoint, :value, :delay_ms]))
    }
  end

  defp build(_kind, _endpoint, _value, _keystroke, _sequence), do: nil
end
