defmodule Trenino.Train.Script do
  @moduledoc """
  Schema for Lua scripts attached to train configurations.

  Scripts watch simulator API endpoints (triggers) and execute a Lua
  `on_change(event)` callback whenever a trigger value changes.

  ## Trigger Format

  Triggers are stored as a JSON-encoded list of simulator endpoint paths:

      ["CurrentDrivableActor/Throttle.InputValue", "CurrentDrivableActor.Function.HUD_GetSpeed"]

  ## Script API

  Scripts have access to:
  - `api.get(path)` / `api.set(path, value)` - Simulator API client
  - `output.set(id, on)` - Hardware output control
  - `schedule(ms)` - Self-scheduling
  - `state` - Persistent in-memory table across invocations
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Train.Train

  @type t :: %__MODULE__{
          id: integer() | nil,
          train_id: integer() | nil,
          name: String.t() | nil,
          enabled: boolean(),
          code: String.t() | nil,
          triggers: [String.t()],
          train: Train.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "scripts" do
    field :name, :string
    field :enabled, :boolean, default: true
    field :code, :string, default: ""
    field :triggers, Trenino.Train.Script.TriggersType, default: []

    belongs_to :train, Train

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = script, attrs) do
    script
    |> cast(attrs, [:train_id, :name, :enabled, :code, :triggers])
    |> validate_required([:train_id, :name, :code])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_triggers()
    |> foreign_key_constraint(:train_id)
    |> unique_constraint([:train_id, :name])
  end

  defp validate_triggers(changeset) do
    case get_field(changeset, :triggers) do
      nil ->
        changeset

      triggers when is_list(triggers) ->
        if Enum.all?(triggers, &is_binary/1) do
          changeset
        else
          add_error(changeset, :triggers, "must be a list of endpoint path strings")
        end

      _ ->
        add_error(changeset, :triggers, "must be a list")
    end
  end
end
