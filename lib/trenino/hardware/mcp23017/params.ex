defmodule Trenino.Hardware.MCP23017.Params do
  @moduledoc """
  Chip-specific configuration for MCP23017 I/O expanders.

  Bit N of a mask is pin N, with GPA0-7 as bits 0-7 and GPB0-7 as bits 8-15.
  GPA7 and GPB7 (bits 7 and 15) are output-only, so they may be matrix rows but
  never direct inputs or matrix columns. The bases are assigned by the virtual
  pin allocator, not by the user.
  """

  use Ecto.Schema
  import Bitwise
  import Ecto.Changeset

  @type t() :: %__MODULE__{
          direct_base: integer(),
          matrix_base: integer(),
          debounce: integer() | nil,
          direct_mask: integer(),
          row_mask: integer(),
          col_mask: integer()
        }

  @output_only_bits 0x8080

  @primary_key false
  embedded_schema do
    field :direct_base, :integer, default: 0
    field :matrix_base, :integer, default: 0
    field :debounce, :integer
    field :direct_mask, :integer, default: 0
    field :row_mask, :integer, default: 0
    field :col_mask, :integer, default: 0
  end

  @doc "Default debounce in sample periods: 3 with no matrix, otherwise 2."
  @spec default_debounce(integer()) :: 3 | 2
  def default_debounce(0), do: 3
  def default_debounce(row_mask) when is_integer(row_mask), do: 2

  @doc "Number of set bits in a mask."
  @spec pin_count(integer()) :: non_neg_integer()
  def pin_count(mask) when is_integer(mask) and mask >= 0 do
    mask |> Integer.digits(2) |> Enum.count(&(&1 == 1))
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = params, attrs) do
    params
    |> cast(attrs, [:direct_base, :matrix_base, :debounce, :direct_mask, :row_mask, :col_mask])
    |> validate_required([:direct_mask, :row_mask, :col_mask])
    |> validate_number(:direct_base, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_number(:matrix_base, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_number(:direct_mask, greater_than_or_equal_to: 0, less_than_or_equal_to: 0xFFFF)
    |> validate_number(:row_mask, greater_than_or_equal_to: 0, less_than_or_equal_to: 0xFFFF)
    |> validate_number(:col_mask, greater_than_or_equal_to: 0, less_than_or_equal_to: 0xFFFF)
    |> put_default_debounce()
    |> validate_number(:debounce, greater_than_or_equal_to: 1, less_than_or_equal_to: 255)
    |> validate_layout()
  end

  defp put_default_debounce(changeset) do
    case get_field(changeset, :debounce) do
      nil -> put_change(changeset, :debounce, default_debounce(get_field(changeset, :row_mask)))
      _ -> changeset
    end
  end

  defp validate_layout(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_layout(changeset) do
    direct = get_field(changeset, :direct_mask)
    rows = get_field(changeset, :row_mask)
    cols = get_field(changeset, :col_mask)

    changeset
    |> validate_overlap(direct, rows, cols)
    |> validate_output_only(direct, cols)
    |> validate_matrix(rows, cols)
    |> validate_not_empty(direct, rows, cols)
  end

  defp validate_overlap(changeset, direct, rows, cols) do
    if (direct &&& rows) != 0 or (direct &&& cols) != 0 or (rows &&& cols) != 0 do
      add_error(changeset, :direct_mask, "pins cannot be used for more than one role")
    else
      changeset
    end
  end

  defp validate_output_only(changeset, direct, cols) do
    changeset =
      if (direct &&& @output_only_bits) != 0 do
        add_error(changeset, :direct_mask, "GPA7 and GPB7 are output-only and cannot be inputs")
      else
        changeset
      end

    if (cols &&& @output_only_bits) != 0 do
      add_error(changeset, :col_mask, "GPA7 and GPB7 are output-only and cannot be columns")
    else
      changeset
    end
  end

  defp validate_matrix(changeset, rows, cols) do
    cond do
      rows == 0 and cols == 0 ->
        changeset

      rows == 0 or cols == 0 ->
        add_error(changeset, :row_mask, "rows and columns must both be set or both be empty")

      true ->
        if pin_count(rows) > 8,
          do: add_error(changeset, :row_mask, "at most 8 rows"),
          else: changeset
    end
  end

  defp validate_not_empty(changeset, 0, 0, 0),
    do: add_error(changeset, :direct_mask, "the chip needs at least one input")

  defp validate_not_empty(changeset, _direct, _rows, _cols), do: changeset
end
