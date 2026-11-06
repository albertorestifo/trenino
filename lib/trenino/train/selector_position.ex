defmodule Trenino.Train.SelectorPosition do
  @moduledoc """
  Schema for one position of a selector (a potentiometer used as a
  multi-position switch).

  ## Hardware Input Range (input_min/input_max)

  Normalized hardware positions from 0.0 to 1.0, matched inclusively on both
  ends. Gaps between positions are dead zones: a reading inside a gap keeps
  the selector in its last position, so nothing fires.

  ## Actions

  Each position has an **enter** action, run when the selector moves into it,
  and an **exit** action, run when it moves out. An action is one of:

  - `:set_value` - set `endpoint` to `value` in the simulator
  - `:sequence` - run the sequence `sequence_id`
  - `:keystroke` - tap `keystroke` (e.g. "L", "CTRL+L")
  - `:none` - do nothing (the default for both)

  Deleting a sequence resets every action that ran it to `:none`.

  Fields are stored flat with an `enter_` or `exit_` prefix.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Train.{SelectorBinding, Sequence}

  @type action_kind :: :none | :set_value | :sequence | :keystroke

  @type t :: %__MODULE__{
          id: integer() | nil,
          selector_binding_id: integer() | nil,
          index: integer() | nil,
          label: String.t() | nil,
          input_min: float() | nil,
          input_max: float() | nil,
          enter_kind: action_kind(),
          enter_endpoint: String.t() | nil,
          enter_value: float() | nil,
          enter_sequence_id: integer() | nil,
          enter_keystroke: String.t() | nil,
          exit_kind: action_kind(),
          exit_endpoint: String.t() | nil,
          exit_value: float() | nil,
          exit_sequence_id: integer() | nil,
          exit_keystroke: String.t() | nil,
          selector_binding: SelectorBinding.t() | Ecto.Association.NotLoaded.t(),
          enter_sequence: Sequence.t() | Ecto.Association.NotLoaded.t() | nil,
          exit_sequence: Sequence.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @action_kinds [:none, :set_value, :sequence, :keystroke]

  schema "selector_positions" do
    field :index, :integer
    field :label, :string
    field :input_min, :float
    field :input_max, :float

    field :enter_kind, Ecto.Enum, values: @action_kinds, default: :none
    field :enter_endpoint, :string
    field :enter_value, :float
    field :enter_keystroke, :string

    field :exit_kind, Ecto.Enum, values: @action_kinds, default: :none
    field :exit_endpoint, :string
    field :exit_value, :float
    field :exit_keystroke, :string

    belongs_to :selector_binding, SelectorBinding
    belongs_to :enter_sequence, Sequence
    belongs_to :exit_sequence, Sequence

    timestamps(type: :utc_datetime)
  end

  @doc "The action kinds a position can use."
  @spec action_kinds() :: [action_kind()]
  def action_kinds, do: @action_kinds

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = position, attrs) do
    position
    |> cast(attrs, [
      :index,
      :label,
      :input_min,
      :input_max,
      :enter_kind,
      :enter_endpoint,
      :enter_value,
      :enter_sequence_id,
      :enter_keystroke,
      :exit_kind,
      :exit_endpoint,
      :exit_value,
      :exit_sequence_id,
      :exit_keystroke
    ])
    |> validate_required([:index, :input_min, :input_max, :enter_kind, :exit_kind])
    |> validate_number(:index, greater_than_or_equal_to: 0)
    |> validate_length(:label, max: 40)
    |> round_float_fields([:input_min, :input_max, :enter_value, :exit_value])
    |> validate_input_range()
    |> validate_action(:enter)
    |> validate_action(:exit)
    |> foreign_key_constraint(:selector_binding_id)
    |> foreign_key_constraint(:enter_sequence_id)
    |> foreign_key_constraint(:exit_sequence_id)
    |> unique_constraint([:selector_binding_id, :index])
  end

  defp validate_input_range(changeset) do
    min_val = get_field(changeset, :input_min)
    max_val = get_field(changeset, :input_max)

    changeset
    |> validate_number(:input_min, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:input_max, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> then(fn cs ->
      if is_number(min_val) and is_number(max_val) and min_val > max_val do
        add_error(cs, :input_min, "must be less than or equal to input_max")
      else
        cs
      end
    end)
  end

  # Requires the fields of the chosen action kind. Fields of other kinds are
  # cleared, so switching kind never leaves a stale endpoint or sequence behind.
  defp validate_action(changeset, prefix) do
    kind_field = action_field(prefix, :kind)
    required = required_fields(get_field(changeset, kind_field), prefix)
    stale = action_fields(prefix) -- required

    changeset
    |> validate_required(required)
    |> clear_fields(stale)
  end

  defp required_fields(:set_value, prefix),
    do: [action_field(prefix, :endpoint), action_field(prefix, :value)]

  defp required_fields(:sequence, prefix), do: [action_field(prefix, :sequence_id)]
  defp required_fields(:keystroke, prefix), do: [action_field(prefix, :keystroke)]
  defp required_fields(_kind, _prefix), do: []

  defp action_fields(prefix),
    do: Enum.map([:endpoint, :value, :sequence_id, :keystroke], &action_field(prefix, &1))

  defp clear_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, cs ->
      if get_field(cs, field) == nil, do: cs, else: put_change(cs, field, nil)
    end)
  end

  defp action_field(:enter, name), do: :"enter_#{name}"
  defp action_field(:exit, name), do: :"exit_#{name}"

  defp round_float_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, cs ->
      case fetch_change(cs, field) do
        {:ok, value} when is_float(value) -> put_change(cs, field, Float.round(value, 2))
        _ -> cs
      end
    end)
  end
end
