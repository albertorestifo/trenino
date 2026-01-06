defmodule TswIo.Train.ButtonInputBinding do
  @moduledoc """
  Schema for binding hardware button inputs to train button elements.

  Associates a device button input with a train element, enabling
  real-time translation of button press/release to simulator values.

  Each button element can have at most one input binding. The same input
  can be bound to different button elements across different trains.

  ## Binding Modes

  The binding supports three modes:

  - **`:simple`** - Default mode. Sends on_value when pressed, off_value when released.
  - **`:momentary`** - Repeats the on_value at a fixed interval while button is held.
    Useful for controls like horn that need continuous "pressed" signals.
  - **`:sequence`** - Executes a sequence of commands when button is pressed.
    Commands are sent in order with configurable delays.
  - **`:keystroke`** - Simulates keyboard input. Holds key down while button pressed,
    releases when button released. Supports modifier combinations (Ctrl, Shift, Alt).

  ## Hardware Types

  - **`:momentary`** - Spring-loaded button that returns when released (e.g., doorbell)
  - **`:latching`** - Toggle switch that stays in position until pressed again
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Hardware.Input
  alias TswIo.Train.Element
  alias TswIo.Train.Sequence

  @type mode :: :simple | :momentary | :sequence | :keystroke
  @type hardware_type :: :momentary | :latching

  @type t :: %__MODULE__{
          id: integer() | nil,
          element_id: integer() | nil,
          input_id: integer() | nil,
          endpoint: String.t() | nil,
          on_value: float(),
          off_value: float(),
          enabled: boolean(),
          mode: mode(),
          hardware_type: hardware_type(),
          repeat_interval_ms: integer(),
          keystroke: String.t() | nil,
          on_sequence_id: integer() | nil,
          off_sequence_id: integer() | nil,
          element: Element.t() | Ecto.Association.NotLoaded.t(),
          input: Input.t() | Ecto.Association.NotLoaded.t(),
          on_sequence: Sequence.t() | Ecto.Association.NotLoaded.t() | nil,
          off_sequence: Sequence.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "button_input_bindings" do
    field :endpoint, :string
    field :on_value, :float, default: 1.0
    field :off_value, :float, default: 0.0
    field :enabled, :boolean, default: true

    # Mode: :simple (send once), :momentary (repeat while held), :sequence (execute sequence), :keystroke (simulate key)
    field :mode, Ecto.Enum, values: [:simple, :momentary, :sequence, :keystroke], default: :simple
    # Keystroke to simulate (e.g., "W", "CTRL+S", "SHIFT+F1") - only used in :keystroke mode
    field :keystroke, :string
    # Hardware type: :momentary (spring-loaded), :latching (stays in position)
    field :hardware_type, Ecto.Enum, values: [:momentary, :latching], default: :momentary
    # Repeat interval for momentary mode (ms)
    field :repeat_interval_ms, :integer, default: 100

    belongs_to :element, Element
    belongs_to :input, Input
    belongs_to :on_sequence, Sequence
    belongs_to :off_sequence, Sequence

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = binding, attrs) do
    binding
    |> cast(attrs, [
      :element_id,
      :input_id,
      :endpoint,
      :on_value,
      :off_value,
      :enabled,
      :mode,
      :hardware_type,
      :repeat_interval_ms,
      :keystroke,
      :on_sequence_id,
      :off_sequence_id
    ])
    |> validate_required([:element_id, :input_id])
    |> validate_mode_requirements()
    |> validate_sequence_requirements()
    |> validate_number(:repeat_interval_ms, greater_than: 0, less_than_or_equal_to: 5000)
    |> round_float_fields([:on_value, :off_value])
    |> foreign_key_constraint(:element_id)
    |> foreign_key_constraint(:input_id)
    |> foreign_key_constraint(:on_sequence_id)
    |> foreign_key_constraint(:off_sequence_id)
    |> unique_constraint(:element_id)
  end

  # Mode-specific validation: simple and momentary modes require endpoint
  defp validate_mode_requirements(changeset) do
    mode = get_field(changeset, :mode)

    case mode do
      :simple ->
        validate_required(changeset, [:endpoint])

      :momentary ->
        changeset
        |> validate_required([:endpoint, :repeat_interval_ms])

      :sequence ->
        # Sequence mode requires on_sequence_id
        validate_required(changeset, [:on_sequence_id])

      :keystroke ->
        # Keystroke mode requires keystroke field
        validate_required(changeset, [:keystroke])

      nil ->
        changeset
    end
  end

  # Validate sequence requirements based on hardware type
  # off_sequence_id is only valid for latching hardware with sequence mode
  defp validate_sequence_requirements(changeset) do
    mode = get_field(changeset, :mode)
    hardware_type = get_field(changeset, :hardware_type)
    off_sequence_id = get_field(changeset, :off_sequence_id)

    # off_sequence is only valid for latching hardware in sequence mode
    if mode != :sequence and off_sequence_id != nil do
      add_error(changeset, :off_sequence_id, "is only valid in sequence mode")
    else
      if mode == :sequence and hardware_type == :momentary and off_sequence_id != nil do
        add_error(changeset, :off_sequence_id, "is only valid for latching hardware")
      else
        changeset
      end
    end
  end

  # Rounds float fields to 2 decimal places per project standards
  # (prevents precision artifacts like -0.20000000298023224)
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
