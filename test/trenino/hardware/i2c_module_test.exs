defmodule Trenino.Hardware.I2cModuleTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware.I2cModule

  defp valid_params(overrides \\ %{}) do
    Map.merge(
      %{brightness: 8, num_digits: 4, display_type: :fourteen_segment, has_dot: false, align_right: true, min_value: 0.0},
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
        device_id: 1, module_chip: :ht16k33, i2c_address: 112,
        params: valid_params(%{brightness: 16})
      }
      changeset = I2cModule.changeset(%I2cModule{}, attrs)
      refute changeset.valid?
    end

    test "invalid num_digits propagates through embed" do
      attrs = %{
        device_id: 1, module_chip: :ht16k33, i2c_address: 112,
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
end
