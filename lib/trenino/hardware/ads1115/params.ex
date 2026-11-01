defmodule Trenino.Hardware.ADS1115.Params do
  @moduledoc """
  Chip-specific configuration for ADS1115 analog converters.

  `channel_mask` bits 0-3 enable channels AIN0-3. `ref_channel` optionally names
  a channel wired to the sensor supply, used as a ratio reference; it must not be
  an enabled input channel. `pin_base` is assigned by the virtual pin allocator.
  """

  use Ecto.Schema
  import Bitwise
  import Ecto.Changeset

  @type t() :: %__MODULE__{
          pin_base: integer(),
          channel_mask: integer(),
          gain: 0 | 1,
          ref_channel: integer() | nil
        }

  @primary_key false
  embedded_schema do
    field :pin_base, :integer, default: 0
    field :channel_mask, :integer
    field :gain, :integer, default: 0
    field :ref_channel, :integer
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = params, attrs) do
    params
    |> cast(attrs, [:pin_base, :channel_mask, :gain, :ref_channel])
    |> validate_required([:channel_mask, :gain])
    |> validate_number(:pin_base, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_number(:channel_mask, greater_than: 0, less_than_or_equal_to: 0x0F)
    |> validate_inclusion(:gain, [0, 1])
    |> validate_number(:ref_channel, greater_than_or_equal_to: 0, less_than_or_equal_to: 3)
    |> validate_ref_channel()
  end

  defp validate_ref_channel(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_ref_channel(changeset) do
    ref = get_field(changeset, :ref_channel)
    mask = get_field(changeset, :channel_mask)

    if is_integer(ref) and (mask &&& 1 <<< ref) != 0 do
      add_error(changeset, :ref_channel, "cannot also be an input channel")
    else
      changeset
    end
  end
end
