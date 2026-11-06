defmodule Trenino.Train.SelectorBinding do
  @moduledoc """
  Schema for binding an analog input to a selector element.

  A selector turns a potentiometer into a multi-position switch: the input's
  normalized range is split into positions (`SelectorPosition`), each with its
  own enter and exit actions.

  Each selector element has at most one binding. Positions are always written
  as a complete set through `changeset/2`, which replaces the previous set.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Hardware.Input
  alias Trenino.Train.{Element, SelectorMapper, SelectorPosition}

  @min_positions 2
  @max_positions 12

  @type t :: %__MODULE__{
          id: integer() | nil,
          element_id: integer() | nil,
          input_id: integer() | nil,
          enabled: boolean(),
          element: Element.t() | Ecto.Association.NotLoaded.t(),
          input: Input.t() | Ecto.Association.NotLoaded.t(),
          positions: [SelectorPosition.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "selector_bindings" do
    field :enabled, :boolean, default: true

    belongs_to :element, Element
    belongs_to :input, Input

    has_many :positions, SelectorPosition,
      on_replace: :delete,
      preload_order: [asc: :index]

    timestamps(type: :utc_datetime)
  end

  @doc "The minimum and maximum number of positions a selector can have."
  @spec position_limits() :: {pos_integer(), pos_integer()}
  def position_limits, do: {@min_positions, @max_positions}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = binding, attrs) do
    binding
    |> cast(attrs, [:element_id, :input_id, :enabled])
    |> validate_required([:element_id, :input_id, :enabled])
    |> cast_assoc(:positions, with: &SelectorPosition.changeset/2)
    |> validate_positions()
    |> foreign_key_constraint(:element_id)
    |> foreign_key_constraint(:input_id)
    |> unique_constraint(:element_id)
  end

  defp validate_positions(changeset) do
    positions =
      changeset
      |> get_assoc(:positions, :struct)
      |> Enum.map(&Map.take(&1, [:index, :input_min, :input_max]))

    cond do
      length(positions) < @min_positions or length(positions) > @max_positions ->
        add_error(
          changeset,
          :positions,
          "must have between #{@min_positions} and #{@max_positions} positions"
        )

      Enum.any?(positions, &(is_nil(&1.index) or is_nil(&1.input_min) or is_nil(&1.input_max))) ->
        # Per-position errors already explain what is missing
        changeset

      length(Enum.uniq_by(positions, & &1.index)) != length(positions) ->
        add_error(changeset, :positions, "must have unique indexes")

      SelectorMapper.validate_layout(positions) == {:error, :overlap} ->
        add_error(
          changeset,
          :positions,
          "must not overlap and need a gap of at least #{SelectorMapper.min_gap()} between them"
        )

      true ->
        changeset
    end
  end
end
