defmodule TswIo.Train.ButtonInputBinding do
  @moduledoc """
  Schema for binding hardware button inputs to train button elements.

  Associates a device button input with a train element, enabling
  real-time translation of button press/release to simulator values.

  Each button element can have at most one input binding. The same input
  can be bound to different button elements across different trains.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Hardware.Input
  alias TswIo.Train.Element

  @type t :: %__MODULE__{
          id: integer() | nil,
          element_id: integer() | nil,
          input_id: integer() | nil,
          endpoint: String.t() | nil,
          on_value: float(),
          off_value: float(),
          enabled: boolean(),
          element: Element.t() | Ecto.Association.NotLoaded.t(),
          input: Input.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "button_input_bindings" do
    field :endpoint, :string
    field :on_value, :float, default: 1.0
    field :off_value, :float, default: 0.0
    field :enabled, :boolean, default: true

    belongs_to :element, Element
    belongs_to :input, Input

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = binding, attrs) do
    binding
    |> cast(attrs, [:element_id, :input_id, :endpoint, :on_value, :off_value, :enabled])
    |> validate_required([:element_id, :input_id, :endpoint])
    |> round_float_fields([:on_value, :off_value])
    |> foreign_key_constraint(:element_id)
    |> foreign_key_constraint(:input_id)
    |> unique_constraint(:element_id)
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
