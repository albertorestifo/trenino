defmodule Trenino.Train.Notch do
  @moduledoc """
  Schema for lever notches.

  A notch represents a discrete position or range on a lever. Notches can be
  of two types:
  - `:gate` - A fixed position with a single value
  - `:linear` - A continuous range with min and max values

  ## Hardware Input Range (input_min/input_max)

  Maps physical lever positions to notches. These values represent normalized
  hardware input positions from 0.0 to 1.0:
  - `0.0` = physical lever at minimum calibrated position
  - `1.0` = physical lever at maximum calibrated position

  These are set during notch calibration when the user moves the physical lever.

  ## Simulator Input Range (sim_input_min/sim_input_max)

  The InputValue to send to the simulator for this notch. These values are
  determined by LeverAnalyzer which sweeps through the simulator to find
  what InputValue produces each notch's output.

  For example, LeverAnalyzer might find that InputValue 0.05-0.45 produces
  braking outputs -10 to -0.91. These become sim_input_min=0.05, sim_input_max=0.45.

  ## Simulator Output Values (value, min_value, max_value)

  The output values the simulator produces. These are informational only and
  not used for mapping - they describe what the simulator outputs when the
  corresponding sim_input range is sent.
  - `value` - for gates (e.g., -11, 0)
  - `min_value`, `max_value` - for linear (e.g., -10 to -0.91)
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Train.LeverConfig

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
          sim_input_min: float() | nil,
          sim_input_max: float() | nil,
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
    # Hardware input range (0.0-1.0 calibrated hardware positions)
    field :input_min, :float
    field :input_max, :float
    # Simulator input range (what InputValue to send to simulator)
    field :sim_input_min, :float
    field :sim_input_max, :float
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
      :sim_input_min,
      :sim_input_max,
      :description,
      :lever_config_id
    ])
    |> round_float_fields([
      :value,
      :min_value,
      :max_value,
      :input_min,
      :input_max,
      :sim_input_min,
      :sim_input_max
    ])
    |> validate_required([:index, :type])
    |> validate_notch_values()
    |> validate_input_range()
    |> validate_sim_input_range()
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
    validate_range_pair(changeset, :input_min, :input_max)
  end

  defp validate_sim_input_range(changeset) do
    validate_range_pair(changeset, :sim_input_min, :sim_input_max)
  end

  # Validates a min/max field pair for normalized 0.0-1.0 ranges
  defp validate_range_pair(changeset, min_field, max_field) do
    min_val = get_field(changeset, min_field)
    max_val = get_field(changeset, max_field)

    changeset
    |> validate_both_set(min_field, max_field, min_val, max_val)
    |> validate_min_lte_max(min_field, max_field, min_val, max_val)
    |> validate_in_range(min_field, min_val)
    |> validate_in_range(max_field, max_val)
  end

  defp validate_both_set(changeset, min_field, max_field, min_val, max_val) do
    cond do
      is_nil(min_val) and is_nil(max_val) ->
        changeset

      is_nil(min_val) or is_nil(max_val) ->
        add_error(changeset, min_field, "both #{min_field} and #{max_field} must be set together")

      true ->
        changeset
    end
  end

  defp validate_min_lte_max(changeset, min_field, max_field, min_val, max_val) do
    if not is_nil(min_val) and not is_nil(max_val) and min_val > max_val do
      add_error(changeset, min_field, "must be less than or equal to #{max_field}")
    else
      changeset
    end
  end

  defp validate_in_range(changeset, _field, nil), do: changeset

  defp validate_in_range(changeset, field, value) do
    if value < 0.0 or value > 1.0 do
      add_error(changeset, field, "must be between 0.0 and 1.0")
    else
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
