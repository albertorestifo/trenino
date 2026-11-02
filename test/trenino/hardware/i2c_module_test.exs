defmodule Trenino.Hardware.I2cModuleTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware.I2cModule

  defp valid_params(overrides \\ %{}) do
    Map.merge(
      %{
        brightness: 8,
        num_digits: 4,
        display_type: :fourteen_segment,
        has_dot: false,
        align_right: true,
        min_value: 0.0
      },
      overrides
    )
  end

  describe "parse_i2c_address/1" do
    test "accepts decimal string" do
      assert {:ok, 112} = I2cModule.parse_i2c_address("112")
    end

    test "accepts lowercase hex string" do
      assert {:ok, 112} = I2cModule.parse_i2c_address("0x70")
    end

    test "uppercase hex prefix is not supported and returns :error" do
      assert :error = I2cModule.parse_i2c_address("0X70")
    end

    test "rejects decimal out of range (256)" do
      assert :error = I2cModule.parse_i2c_address("256")
    end

    test "rejects negative decimal" do
      assert :error = I2cModule.parse_i2c_address("-1")
    end

    test "rejects non-numeric string" do
      assert :error = I2cModule.parse_i2c_address("abc")
    end

    test "accepts boundary value 0" do
      assert {:ok, 0} = I2cModule.parse_i2c_address("0")
    end

    test "accepts boundary value 255" do
      assert {:ok, 255} = I2cModule.parse_i2c_address("255")
    end
  end

  describe "format_i2c_address/1" do
    test "formats 0x70 (112) as '112 (0x70)'" do
      assert "112 (0x70)" = I2cModule.format_i2c_address(0x70)
    end

    test "formats 0 as '0 (0x00)'" do
      assert "0 (0x00)" = I2cModule.format_i2c_address(0)
    end

    test "formats 255 as '255 (0xFF)'" do
      assert "255 (0xFF)" = I2cModule.format_i2c_address(255)
    end
  end

  describe "changeset/2 – core fields" do
    test "valid attrs with params produce a valid changeset" do
      attrs = %{device_id: 1, module_chip: :ht16k33, i2c_address: 112, params: valid_params()}
      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      assert changeset.valid?
    end

    test "requires device_id" do
      attrs = %{module_chip: :ht16k33, i2c_address: 112, params: valid_params()}
      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      assert "can't be blank" in errors_on(changeset).device_id
    end

    test "requires module_chip" do
      attrs = %{device_id: 1, i2c_address: 112, params: valid_params()}
      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      assert "can't be blank" in errors_on(changeset).module_chip
    end

    test "requires i2c_address" do
      attrs = %{device_id: 1, module_chip: :ht16k33, params: valid_params()}
      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      assert "can't be blank" in errors_on(changeset).i2c_address
    end

    test "rejects i2c_address below 0" do
      attrs = %{device_id: 1, module_chip: :ht16k33, i2c_address: -1, params: valid_params()}
      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      assert errors_on(changeset).i2c_address != []
    end

    test "rejects i2c_address above 255" do
      attrs = %{device_id: 1, module_chip: :ht16k33, i2c_address: 256, params: valid_params()}
      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      assert errors_on(changeset).i2c_address != []
    end

    test "rejects name longer than 100 characters" do
      attrs = %{
        device_id: 1,
        module_chip: :ht16k33,
        i2c_address: 112,
        params: valid_params(),
        name: String.duplicate("a", 101)
      }

      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      assert errors_on(changeset).name != []
    end

    test "rejects unknown module_chip value" do
      attrs = %{device_id: 1, module_chip: :unknown_chip, i2c_address: 112}
      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      assert errors_on(changeset).module_chip != []
    end
  end

  describe "changeset/2 – params embed" do
    test "invalid brightness propagates through embed" do
      attrs = %{
        device_id: 1,
        module_chip: :ht16k33,
        i2c_address: 112,
        params: valid_params(%{brightness: 16})
      }

      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      refute changeset.valid?
    end

    test "invalid num_digits propagates through embed" do
      attrs = %{
        device_id: 1,
        module_chip: :ht16k33,
        i2c_address: 112,
        params: valid_params(%{num_digits: 6})
      }

      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      refute changeset.valid?
    end

    test "requires params" do
      attrs = %{device_id: 1, module_chip: :ht16k33, i2c_address: 112}
      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      refute changeset.valid?
    end
  end

  describe "MCP23017" do
    defp mcp(params, addr \\ 0x20) do
      base = %{direct_mask: 0, row_mask: 0, col_mask: 0}

      I2cModule.changeset(%I2cModule{}, %{
        device_id: 1,
        module_chip: :mcp23017,
        i2c_address: addr,
        params: Map.merge(base, params)
      })
    end

    test "valid direct-only chip" do
      assert mcp(%{direct_mask: 0x0003}).valid?
    end

    test "rejects overlapping masks" do
      refute mcp(%{direct_mask: 0x0001, row_mask: 0x0001, col_mask: 0x0002}).valid?
      refute mcp(%{direct_mask: 0x0004, row_mask: 0x0001, col_mask: 0x0004}).valid?
    end

    test "rejects bit 7 or 15 in direct or col" do
      refute mcp(%{direct_mask: 0x0080}).valid?
      refute mcp(%{direct_mask: 0x8000}).valid?
      refute mcp(%{row_mask: 0x0001, col_mask: 0x0080}).valid?
      refute mcp(%{row_mask: 0x0001, col_mask: 0x8000}).valid?
    end

    test "rejects more than 8 rows or cols" do
      refute mcp(%{row_mask: 0x01FF, col_mask: 0x0200}).valid?
      cs = mcp(%{row_mask: 0x0001, col_mask: 0x7F7E})
      assert {"at most 8 columns", _} = cs.changes.params.errors[:col_mask]
    end

    test "rejects rows without cols and cols without rows" do
      refute mcp(%{row_mask: 0x0001}).valid?
      refute mcp(%{col_mask: 0x0001}).valid?
    end

    test "rejects an empty chip" do
      refute mcp(%{}).valid?
    end

    test "rejects address 0x28" do
      cs = mcp(%{direct_mask: 1}, 0x28)
      assert errors_on(cs).i2c_address != []
    end

    test "8 rows including both output-only pins with 8 columns spanning both ports is valid" do
      assert mcp(%{row_mask: 0x80BF, col_mask: 0x7F40}).valid?
    end

    test "debounce defaults from layout" do
      assert {:ok, %{params: %{debounce: 3}}} =
               Ecto.Changeset.apply_action(mcp(%{direct_mask: 1}), :insert)

      assert {:ok, %{params: %{debounce: 2}}} =
               Ecto.Changeset.apply_action(mcp(%{row_mask: 1, col_mask: 2}), :insert)
    end

    test "debounce range is 1-255" do
      refute mcp(%{direct_mask: 1, debounce: 0}).valid?
      refute mcp(%{direct_mask: 1, debounce: 256}).valid?
      assert mcp(%{direct_mask: 1, debounce: 255}).valid?
    end
  end

  describe "ADS1115" do
    defp ads(params, addr \\ 0x48) do
      I2cModule.changeset(%I2cModule{}, %{
        device_id: 1,
        module_chip: :ads1115,
        i2c_address: addr,
        params: Map.merge(%{channel_mask: 0x01, gain: 0}, params)
      })
    end

    test "valid chip" do
      assert ads(%{}).valid?
      assert ads(%{channel_mask: 0x07, ref_channel: 3, gain: 1}).valid?
    end

    test "rejects gain other than 0 or 1" do
      refute ads(%{gain: 2}).valid?
    end

    test "rejects ref_channel inside channel_mask" do
      refute ads(%{channel_mask: 0x03, ref_channel: 1}).valid?
    end

    test "rejects ref_channel outside 0-3" do
      refute ads(%{ref_channel: 4}).valid?
    end

    test "rejects a chip with no channels" do
      refute ads(%{channel_mask: 0}).valid?
    end

    test "rejects address 0x20" do
      assert errors_on(ads(%{}, 0x20)).i2c_address != []
    end
  end

  describe "chip invariants" do
    test "HT16K33 changesets unchanged" do
      cs =
        I2cModule.changeset(%I2cModule{}, %{
          device_id: 1,
          module_chip: :ht16k33,
          i2c_address: 0x00,
          params: valid_params()
        })

      assert cs.valid?
    end

    test "input_chip?/1" do
      assert I2cModule.input_chip?(%I2cModule{module_chip: :mcp23017})
      assert I2cModule.input_chip?(%I2cModule{module_chip: :ads1115})
      refute I2cModule.input_chip?(%I2cModule{module_chip: :ht16k33})
    end

    test "module_chip cannot change on update" do
      existing = %I2cModule{id: 1, module_chip: :ht16k33, i2c_address: 0x70, device_id: 1}
      cs = I2cModule.changeset(existing, %{module_chip: :ads1115, i2c_address: 0x48})
      assert errors_on(cs).module_chip != []
    end
  end
end
