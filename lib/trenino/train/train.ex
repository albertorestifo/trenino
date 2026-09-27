defmodule Trenino.Train.Train do
  @moduledoc """
  Schema for train configurations.

  Each train represents a simulator vehicle identified by one or more equivalent
  ObjectClass prefixes. A train can have multiple elements (levers, buttons, etc.)
  that map to simulator API endpoints.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Train.{Element, TrainIdentifier}

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          identifiers: [TrainIdentifier.t()] | Ecto.Association.NotLoaded.t(),
          elements: [Element.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "trains" do
    field :name, :string
    field :description, :string
    has_many :elements, Element
    has_many :identifiers, TrainIdentifier, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = train, attrs) do
    train
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> cast_assoc(:identifiers,
      with: &TrainIdentifier.changeset/2,
      sort_param: :identifiers_sort,
      drop_param: :identifiers_drop
    )
    |> validate_identifier_collection()
  end

  @spec identifier_values(t()) :: [String.t()]
  def identifier_values(%__MODULE__{identifiers: identifiers}) when is_list(identifiers) do
    identifiers
    |> Enum.map(& &1.identifier)
    |> Enum.sort()
  end

  defp validate_identifier_collection(changeset) do
    case get_change(changeset, :identifiers) do
      identifiers when is_list(identifiers) ->
        retained_identifiers =
          Enum.reject(identifiers, &(&1.action in [:delete, :replace]))

        changeset
        |> require_identifier(retained_identifiers)
        |> reject_duplicate_identifiers(retained_identifiers)

      nil ->
        case changeset.data do
          %__MODULE__{__meta__: %{state: :built}} ->
            add_error(changeset, :identifiers, "must have at least one identifier")

          %__MODULE__{identifiers: []} ->
            add_error(changeset, :identifiers, "must have at least one identifier")

          _loaded_or_not_loaded ->
            changeset
        end
    end
  end

  defp require_identifier(changeset, []),
    do: add_error(changeset, :identifiers, "must have at least one identifier")

  defp require_identifier(changeset, _identifiers), do: changeset

  defp reject_duplicate_identifiers(changeset, identifiers) do
    values = Enum.map(identifiers, &get_field(&1, :identifier))

    if Enum.uniq(values) == values do
      changeset
    else
      add_error(changeset, :identifiers, "must be unique within a train profile")
    end
  end
end
