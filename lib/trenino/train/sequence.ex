defmodule Trenino.Train.Sequence do
  @moduledoc """
  A reusable command sequence that can be triggered by button bindings.

  Sequences belong to a train and contain ordered commands.
  Multiple buttons can reference the same sequence.

  ## Example

      # Create a door opening sequence
      {:ok, sequence} = Train.create_sequence(train_id, %{name: "Door Open"})

      # Add commands to the sequence
      Train.set_sequence_commands(sequence, [
        %{endpoint: "DoorKey.InputValue", value: 1.0, delay_ms: 500},
        %{endpoint: "DoorRotary.InputValue", value: 0.5, delay_ms: 250},
        %{endpoint: "DoorOpen.InputValue", value: 1.0, delay_ms: 0}
      ])
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Train.SequenceCommand
  alias Trenino.Train.Train

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          train_id: integer() | nil,
          train: Train.t() | Ecto.Association.NotLoaded.t(),
          commands: [SequenceCommand.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "sequences" do
    field :name, :string

    belongs_to :train, Train
    has_many :commands, SequenceCommand, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = sequence, attrs) do
    sequence
    |> cast(attrs, [:name, :train_id])
    |> validate_required([:name, :train_id])
    |> validate_length(:name, min: 1, max: 100)
    |> foreign_key_constraint(:train_id)
    |> unique_constraint([:train_id, :name])
  end

  @doc """
  Returns the total duration of the sequence in milliseconds.
  This is the sum of all command delays (not including execution time).
  """
  @spec total_duration(t()) :: integer()
  def total_duration(%__MODULE__{commands: commands}) when is_list(commands) do
    Enum.reduce(commands, 0, fn cmd, acc -> acc + (cmd.delay_ms || 0) end)
  end

  def total_duration(%__MODULE__{}), do: 0
end
