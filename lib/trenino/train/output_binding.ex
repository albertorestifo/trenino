defmodule Trenino.Train.OutputBinding do
  @moduledoc """
  Schema for binding train outputs to API values.

  Monitors a simulator API endpoint via subscription and controls
  a hardware output (LED) based on a condition.

  ## Supported Operators

  Numeric operators:
  - `:gt` - Greater than (value > threshold)
  - `:gte` - Greater than or equal (value >= threshold)
  - `:lt` - Less than (value < threshold)
  - `:lte` - Less than or equal (value <= threshold)
  - `:between` - Between two values inclusive (value_a <= value <= value_b)

  Boolean operators:
  - `:eq_true` - Value equals true (LED on when true)
  - `:eq_false` - Value equals false (LED on when false)

  ## Output Types

  - `:led` - Digital on/off LED output
  - (Future: additional output types may be supported)
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Hardware.Output
  alias Trenino.Train.Train

  @type operator :: :gt | :gte | :lt | :lte | :between | :eq_true | :eq_false
  @type output_type :: :led

  @type t :: %__MODULE__{
          id: integer() | nil,
          train_id: integer() | nil,
          name: String.t() | nil,
          output_type: output_type(),
          output_id: integer() | nil,
          endpoint: String.t() | nil,
          operator: operator() | nil,
          value_a: float() | nil,
          value_b: float() | nil,
          enabled: boolean(),
          train: Train.t() | Ecto.Association.NotLoaded.t(),
          output: Output.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "train_output_bindings" do
    field :name, :string
    field :output_type, Ecto.Enum, values: [:led], default: :led
    field :endpoint, :string
    field :operator, Ecto.Enum, values: [:gt, :gte, :lt, :lte, :between, :eq_true, :eq_false]
    field :value_a, :float
    field :value_b, :float
    field :enabled, :boolean, default: true

    belongs_to :train, Train
    belongs_to :output, Output

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = binding, attrs) do
    binding
    |> cast(attrs, [
      :train_id,
      :name,
      :output_type,
      :output_id,
      :endpoint,
      :operator,
      :value_a,
      :value_b,
      :enabled
    ])
    |> validate_required([:train_id, :name, :output_id, :endpoint, :operator])
    |> validate_numeric_operator_requires_value_a()
    |> validate_between_requires_value_b()
    |> round_float_fields([:value_a, :value_b])
    |> foreign_key_constraint(:train_id)
    |> foreign_key_constraint(:output_id)
    |> unique_constraint([:train_id, :output_id])
  end

  @boolean_operators [:eq_true, :eq_false]

  defp validate_numeric_operator_requires_value_a(changeset) do
    operator = get_field(changeset, :operator)

    if operator in @boolean_operators do
      changeset
    else
      validate_required(changeset, [:value_a])
    end
  end

  defp validate_between_requires_value_b(changeset) do
    if get_field(changeset, :operator) == :between do
      validate_required(changeset, [:value_b])
    else
      changeset
    end
  end

  defp round_float_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      case fetch_change(acc, field) do
        {:ok, value} when is_float(value) ->
          put_change(acc, field, Float.round(value, 2))

        _ ->
          acc
      end
    end)
  end
end
