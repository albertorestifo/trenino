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

      # Min must be less than or equal to max (equal is valid for gate notches with narrow detent)
      input_min > input_max ->
        changeset
        |> add_error(:input_min, "must be less than or equal to input_max")

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

  defp validate_sim_input_range(changeset) do
    sim_input_min = get_field(changeset, :sim_input_min)
    sim_input_max = get_field(changeset, :sim_input_max)

    cond do
      # Both nil is valid (no sim input mapping yet)
      is_nil(sim_input_min) and is_nil(sim_input_max) ->
        changeset

      # One set but not the other
      is_nil(sim_input_min) or is_nil(sim_input_max) ->
        changeset
        |> add_error(:sim_input_min, "both sim_input_min and sim_input_max must be set together")

      # Min must be less than or equal to max
      sim_input_min > sim_input_max ->
        changeset
        |> add_error(:sim_input_min, "must be less than or equal to sim_input_max")

      # Values must be in 0.0-1.0 range (simulator InputValue range)
      sim_input_min < 0.0 or sim_input_min > 1.0 ->
        changeset
        |> add_error(:sim_input_min, "must be between 0.0 and 1.0")

      sim_input_max < 0.0 or sim_input_max > 1.0 ->
        changeset
        |> add_error(:sim_input_max, "must be between 0.0 and 1.0")

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
