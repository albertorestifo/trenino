defmodule Trenino.Hardware.I2cModule do
  @moduledoc "Schema for I2C-attached modules on a device (e.g. HT16K33 display)."

  use Ecto.Schema
  import Ecto.Changeset
  import PolymorphicEmbed

  alias Trenino.Hardware.ADS1115.Params, as: ADS1115Params
  alias Trenino.Hardware.Device
  alias Trenino.Hardware.HT16K33.Params, as: HT16K33Params
  alias Trenino.Hardware.Input
  alias Trenino.Hardware.MCP23017.Params, as: MCP23017Params

  @type module_chip :: :ht16k33 | :mcp23017 | :ads1115

  @address_ranges %{mcp23017: 0x20..0x27, ads1115: 0x48..0x4B}

  @type t() :: %__MODULE__{
          id: integer() | nil,
          device_id: integer() | nil,
          name: String.t() | nil,
          module_chip: module_chip(),
          i2c_address: integer() | nil,
          params: HT16K33Params.t() | MCP23017Params.t() | ADS1115Params.t() | nil,
          device: Device.t() | Ecto.Association.NotLoaded.t(),
          inputs: [Input.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "device_i2c_modules" do
    field :name, :string
    field :module_chip, Ecto.Enum, values: [:ht16k33, :mcp23017, :ads1115]
    field :i2c_address, :integer

    polymorphic_embeds_one(:params,
      types: [
        ht16k33: [
          module: HT16K33Params,
          identify_by_fields: [:brightness, :num_digits, :display_type, :has_dot]
        ],
        mcp23017: [
          module: MCP23017Params,
          identify_by_fields: [:direct_mask, :row_mask, :col_mask]
        ],
        ads1115: [
          module: ADS1115Params,
          identify_by_fields: [:channel_mask, :gain]
        ]
      ],
      on_type_not_found: :raise,
      on_replace: :update
    )

    belongs_to :device, Device
    has_many :inputs, Input
    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = mod, attrs) do
    mod
    |> cast(attrs, [:device_id, :name, :module_chip, :i2c_address])
    |> cast_polymorphic_embed(:params, required: true)
    |> validate_required([:device_id, :module_chip, :i2c_address])
    |> validate_number(:i2c_address, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_chip_address()
    |> validate_chip_immutable(mod)
    |> validate_length(:name, max: 100)
    |> foreign_key_constraint(:device_id)
    |> unique_constraint([:device_id, :i2c_address])
  end

  @doc "True for chips that provide inputs (MCP23017, ADS1115)."
  @spec input_chip?(t()) :: boolean()
  def input_chip?(%__MODULE__{module_chip: chip}), do: chip in [:mcp23017, :ads1115]

  defp validate_chip_address(changeset) do
    with chip when is_map_key(@address_ranges, chip) <- get_field(changeset, :module_chip),
         addr when is_integer(addr) <- get_field(changeset, :i2c_address),
         range = Map.fetch!(@address_ranges, chip),
         false <- addr in range do
      add_error(
        changeset,
        :i2c_address,
        "must be between #{format_i2c_address(range.first)} and #{format_i2c_address(range.last)} for this chip"
      )
    else
      _ -> changeset
    end
  end

  defp validate_chip_immutable(changeset, %__MODULE__{id: id, module_chip: current})
       when not is_nil(id) and not is_nil(current) do
    case fetch_change(changeset, :module_chip) do
      {:ok, new} when new != current ->
        add_error(changeset, :module_chip, "cannot be changed after creation")

      _ ->
        changeset
    end
  end

  defp validate_chip_immutable(changeset, _mod), do: changeset

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
