defmodule TswIo.Hardware.Output do
  @moduledoc """
  Schema for device output configuration (LEDs, indicators, etc.).

  Outputs are stored in the database but are NOT part of the device's
  on-board configuration. They are controlled via SetOutput commands.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TswIo.Hardware.Device

  schema "device_outputs" do
    field :pin, :integer
    field :name, :string

    belongs_to :device, Device

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(%__MODULE__{} = output, attrs) do
    output
    |> cast(attrs, [:pin, :name, :device_id])
    |> validate_required([:pin, :device_id])
    |> validate_number(:pin, greater_than_or_equal_to: 0, less_than: 256)
    |> validate_length(:name, max: 100)
    |> unique_constraint([:device_id, :pin])
  end
end
