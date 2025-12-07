defmodule TswIo.Train.Notch do
  @moduledoc """
  Schema for lever notches.

  A notch represents a discrete position or range on a lever. Notches can be
  of two types:
  - `:gate` - A fixed position with a single value
  - `:linear` - A continuous range with min and max values

  ## Input Range Mapping

  The `input_min` and `input_max` fields map physical lever positions to notches.
  These values represent normalized hardware input positions from 0.0 to 1.0:
  - `0.0` = physical lever at minimum calibrated position
  - `1.0` = physical lever at maximum calibrated position

  For example, if a throttle lever physically moves through positions 0-800
  (after calibration normalization), and notch 0 covers the first 25% of travel:
  - `input_min: 0.0, input_max: 0.25` (not 0-200)

  These normalized values are independent of the specific hardware characteristics,
  making lever configurations portable across different input devices.

  ## Simulator Values

  The `value`, `min_value`, and `max_value` fields represent simulator values
  and can be any float, including negative numbers:
  - Throttle: typically `0.0` to `1.0`
  - Reverser: typically `-1.0` to `1.0`
  - Dynamic brake: might be `-0.45` to `0.0`
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Train.LeverConfig

  @type notch_type :: :gate | :linear

  @type t :: %__MODULE__{
          id: integer() | nil,
          lever_config_id: integer() | nil,
          index: integer() | nil,
          type: notch_type() | nil,
          value: float() | nil,
          min_value: float() | nil,
          max_value: float() | nil,
          input_min: float() | nil,
          input_max: float() | nil,
          description: String.t() | nil,
          lever_config: LeverConfig.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "train_lever_notches" do
    field :index, :integer
    field :type, Ecto.Enum, values: [:gate, :linear]
    field :value, :float
    field :min_value, :float
    field :max_value, :float
    # Input range mapping (0.0-1.0 calibrated input values)
    field :input_min, :float
    field :input_max, :float
    field :description, :string

    belongs_to :lever_config, LeverConfig

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = notch, attrs) do
    notch
    |> cast(attrs, [
      :index,
      :type,
      :value,
      :min_value,
      :max_value,
      :input_min,
      :input_max,
      :description,
      :lever_config_id
    ])
    |> round_float_fields([:value, :min_value, :max_value, :input_min, :input_max])
    |> validate_required([:index, :type])
    |> validate_notch_values()
    |> validate_input_range()
    |> foreign_key_constraint(:lever_config_id)
    |> unique_constraint([:lever_config_id, :index])
  end

  defp validate_notch_values(changeset) do
    case get_field(changeset, :type) do
      :gate ->
        changeset
        |> validate_required([:value])

      :linear ->
        changeset
        |> validate_required([:min_value, :max_value])

      _ ->
        changeset
    end
  end

  defp validate_input_range(changeset) do
    input_min = get_field(changeset, :input_min)
    input_max = get_field(changeset, :input_max)

    cond do
      # Both nil is valid (no input mapping yet)
      is_nil(input_min) and is_nil(input_max) ->
        changeset

      # One set but not the other
      is_nil(input_min) or is_nil(input_max) ->
        changeset
        |> add_error(:input_min, "both input_min and input_max must be set together")

      # Min must be less than max
      input_min >= input_max ->
        changeset
        |> add_error(:input_min, "must be less than input_max")

      # Values must be in 0.0-1.0 range
      input_min < 0.0 or input_min > 1.0 ->
        changeset
        |> add_error(:input_min, "must be between 0.0 and 1.0")

      input_max < 0.0 or input_max > 1.0 ->
        changeset
        |> add_error(:input_max, "must be between 0.0 and 1.0")

      true ->
        changeset
    end
  end

  # Round float fields to 2 decimal places to avoid precision artifacts
  defp round_float_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, cs ->
      case get_change(cs, field) do
        nil -> cs
        value when is_float(value) -> put_change(cs, field, Float.round(value, 2))
        _ -> cs
      end
    end)
  end
end
