defmodule Trenino.Hardware.HT16K33.Params do
  @moduledoc "Chip-specific configuration for HT16K33 LED display drivers."

  use Ecto.Schema
  import Ecto.Changeset

  @type display_type :: :seven_segment | :fourteen_segment
  @type orientation :: :normal | :rotated_180 | :flipped_horizontal | :flipped_vertical

  @type t() :: %__MODULE__{
          brightness: integer(),
          num_digits: integer(),
          display_type: display_type(),
          has_dot: boolean(),
          align_right: boolean(),
          min_value: float() | nil,
          orientation: orientation()
        }

  @primary_key false
  embedded_schema do
    field :brightness, :integer, default: 8
    field :num_digits, :integer, default: 4

    field :display_type, Ecto.Enum,
      values: [:seven_segment, :fourteen_segment],
      default: :fourteen_segment

    field :has_dot, :boolean, default: false
    field :align_right, :boolean, default: true
    field :min_value, :float, default: 0.0

    field :orientation, Ecto.Enum,
      values: [:normal, :rotated_180, :flipped_horizontal, :flipped_vertical],
      default: :normal
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = params, attrs) do
    params
    |> cast(attrs, [
      :brightness,
      :num_digits,
      :display_type,
      :has_dot,
      :align_right,
      :min_value,
      :orientation
    ])
    |> validate_required([
      :brightness,
      :num_digits,
      :display_type,
      :has_dot,
      :align_right,
      :orientation
    ])
    |> validate_number(:brightness, greater_than_or_equal_to: 0, less_than_or_equal_to: 15)
    |> validate_inclusion(:num_digits, [4, 8])
  end
end
