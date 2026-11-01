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

  @input_chips [:mcp23017, :ads1115]

  @address_ranges %{mcp23017: 0x20..0x27, ads1115: 0x48..0x4B}

  @params_modules %{
    ht16k33: HT16K33Params,
    mcp23017: MCP23017Params,
    ads1115: ADS1115Params
  }

  # Must match identify_by_fields below.
  @identify_fields [
    ["brightness", "num_digits", "display_type", "has_dot"],
    ["direct_mask", "row_mask", "col_mask"],
    ["channel_mask", "gain"]
  ]

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
      on_type_not_found: :changeset_error,
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
    |> put_params_type()
    |> cast_polymorphic_embed(:params, required: true)
    |> validate_params_match_chip()
    |> validate_required([:device_id, :module_chip, :i2c_address])
    |> validate_number(:i2c_address, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_chip_address()
    |> validate_immutable(:module_chip, mod)
    |> validate_immutable(:device_id, mod)
    |> validate_length(:name, max: 100)
    |> foreign_key_constraint(:device_id)
    |> unique_constraint([:device_id, :i2c_address])
  end

  @doc "True for chips that provide inputs (MCP23017, ADS1115)."
  @spec input_chip?(t()) :: boolean()
  def input_chip?(%__MODULE__{module_chip: chip}), do: chip in @input_chips

  @doc "The chips that provide inputs."
  @spec input_chips() :: [atom()]
  def input_chips, do: @input_chips

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

  defp validate_immutable(changeset, _field, %__MODULE__{id: nil}), do: changeset

  defp validate_immutable(changeset, field, %__MODULE__{} = mod) do
    case fetch_change(changeset, field) do
      {:ok, new} when new != :erlang.map_get(field, mod) ->
        add_error(changeset, field, "cannot be changed after creation")

      _ ->
        changeset
    end
  end

  # Partial params cannot identify their own type, so the chip names it. Params
  # that do identify a type keep it, for validate_params_match_chip/1 to judge.
  defp put_params_type(changeset) do
    case {get_field(changeset, :module_chip), changeset.params} do
      {chip, %{"params" => %{} = params}} when not is_nil(chip) ->
        if identifies_type?(params) do
          changeset
        else
          typed = Map.put(params, type_key(params), chip)
          %{changeset | params: Map.put(changeset.params, "params", typed)}
        end

      _ ->
        changeset
    end
  end

  defp identifies_type?(params) do
    keys = MapSet.new(Map.keys(params), &to_string/1)

    MapSet.member?(keys, "__type__") or
      Enum.any?(@identify_fields, fn fields -> Enum.all?(fields, &MapSet.member?(keys, &1)) end)
  end

  defp type_key(params) do
    if Enum.any?(Map.keys(params), &is_binary/1), do: "__type__", else: :__type__
  end

  defp validate_params_match_chip(changeset) do
    expected = Map.get(@params_modules, get_field(changeset, :module_chip))

    case get_field(changeset, :params) do
      %{__struct__: module} when module != expected and module != Ecto.Changeset ->
        add_error(changeset, :params, "do not match this chip")

      _ ->
        changeset
    end
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
