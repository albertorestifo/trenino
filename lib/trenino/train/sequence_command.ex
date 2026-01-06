defmodule Trenino.Train.SequenceCommand do
  @moduledoc """
  Individual command within a sequence.

  Commands are executed in order by position.
  The `delay_ms` specifies the wait time AFTER this command before the next.

  ## Fields

  - `position` - Order in sequence (0, 1, 2...)
  - `endpoint` - Simulator API path (e.g., "CurrentDrivableActor/Horn.InputValue")
  - `value` - Float value to send (rounded to 2 decimal places)
  - `delay_ms` - Delay in milliseconds after this command before the next
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Train.Sequence

  @type t :: %__MODULE__{
          id: integer() | nil,
          sequence_id: integer() | nil,
          position: integer() | nil,
          endpoint: String.t() | nil,
          value: float() | nil,
          delay_ms: integer(),
          sequence: Sequence.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "sequence_commands" do
    field :position, :integer
    field :endpoint, :string
    field :value, :float
    field :delay_ms, :integer, default: 0

    belongs_to :sequence, Sequence

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = command, attrs) do
    command
    |> cast(attrs, [:sequence_id, :position, :endpoint, :value, :delay_ms])
    |> validate_required([:sequence_id, :position, :endpoint, :value])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_number(:delay_ms, greater_than_or_equal_to: 0, less_than_or_equal_to: 60_000)
    |> round_float_field(:value)
    |> foreign_key_constraint(:sequence_id)
    |> unique_constraint([:sequence_id, :position])
  end

  # Rounds value to 2 decimal places per project standards
  defp round_float_field(changeset, field) do
    case fetch_change(changeset, field) do
      {:ok, value} when is_float(value) ->
        put_change(changeset, field, Float.round(value, 2))

      _ ->
        changeset
    end
  end
end
