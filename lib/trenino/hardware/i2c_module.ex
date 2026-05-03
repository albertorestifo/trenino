defmodule Trenino.Hardware.I2cModule do
  @moduledoc "Schema for I2C-attached modules on a device (e.g. HT16K33 14-segment display)."

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Hardware.Device

  @type module_chip :: :ht16k33

  @type t() :: %__MODULE__{
          id: integer() | nil,
          device_id: integer() | nil,
          name: String.t() | nil,
          module_chip: module_chip(),
          i2c_address: integer() | nil,
          brightness: integer() | nil,
          num_digits: integer() | nil,
          device: Device.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "device_i2c_modules" do
    field :name, :string
    field :module_chip, Ecto.Enum, values: [:ht16k33]
    field :i2c_address, :integer
    field :brightness, :integer, default: 8
    field :num_digits, :integer, default: 4

    belongs_to :device, Device
    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = mod, attrs) do
    mod
    |> cast(attrs, [:device_id, :name, :module_chip, :i2c_address, :brightness, :num_digits])
    |> validate_required([:device_id, :module_chip, :i2c_address])
    |> validate_number(:i2c_address, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_number(:brightness, greater_than_or_equal_to: 0, less_than_or_equal_to: 15)
    |> validate_inclusion(:num_digits, [4, 8])
    |> validate_length(:name, max: 100)
    |> foreign_key_constraint(:device_id)
    |> unique_constraint([:device_id, :i2c_address])
  end

  @doc "Parse an i2c address string — accepts decimal ('112') or lowercase hex ('0x70'). Uppercase prefix ('0X70') is not supported."
  @spec parse_i2c_address(String.t()) :: {:ok, integer()} | :error
  def parse_i2c_address("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {n, ""} when n in 0..255 -> {:ok, n}
      _ -> :error
    end
  end

  def parse_i2c_address(dec) do
    case Integer.parse(dec) do
      {n, ""} when n in 0..255 -> {:ok, n}
      _ -> :error
    end
  end

  @doc "Format an integer i2c address as '112 (0x70)' for display."
  @spec format_i2c_address(integer()) :: String.t()
  def format_i2c_address(addr) when is_integer(addr) do
    "#{addr} (0x#{Integer.to_string(addr, 16) |> String.pad_leading(2, "0")})"
  end
end
