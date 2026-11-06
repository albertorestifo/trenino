defmodule Trenino.Train.SelectorBinding do
  @moduledoc """
  Schema for binding an analog input to a selector element.

  A selector turns a potentiometer into a multi-position switch: the input's
  normalized range is split into positions (`SelectorPosition`), each with its
  own enter and exit actions.

  Each selector element has at most one binding. When `changeset/2` is given
  positions, they replace the previous set; without them the existing
  positions are kept. Indexes run from 0 to count - 1, in the order the knob
  passes through the positions. Ranges may run either way, so a pot wired in
  reverse puts index 0 at the high end.
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

  @typedoc """
  A validation error: `nil` for the binding, or the position index it
  belongs to.
  """
  @type error :: {non_neg_integer() | nil, atom(), String.t()}

  @doc """
  List a changeset's errors with the position each belongs to.

  Positions being replaced are skipped, and binding-level `:positions`
  errors are kept next to the positions' own errors. Callers format the
  list for their audience.
  """
  @spec errors(Ecto.Changeset.t()) :: [error()]
  def errors(%Ecto.Changeset{} = changeset) do
    binding_errors = for {field, error} <- changeset.errors, do: {nil, field, message(error)}

    position_errors =
      changeset.changes
      |> Map.get(:positions, [])
      |> Enum.reject(&(&1.action == :replace))
      |> Enum.flat_map(fn %Ecto.Changeset{} = position ->
        index = Ecto.Changeset.get_field(position, :index)
        for {field, error} <- position.errors, do: {index, field, message(error)}
      end)

    binding_errors ++ position_errors
  end

  defp message({message, opts}) do
    Regex.replace(~r"%{(\w+)}", message, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
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

      Enum.sort(Enum.map(positions, & &1.index)) != Enum.to_list(0..(length(positions) - 1)) ->
        add_error(changeset, :positions, "must be numbered 0 to #{length(positions) - 1}")

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
