defmodule Trenino.Hardware.ConfigFingerprintTest do
  use ExUnit.Case, async: true

  alias Trenino.Hardware
  alias Trenino.Hardware.{Device, I2cModule}
  alias Trenino.Hardware.HT16K33.Params

  defp display(params \\ %{}) do
    %I2cModule{
      module_chip: :ht16k33,
      i2c_address: 0x70,
      name: "Speed",
      params: struct(Params, params)
    }
  end

  defp fingerprint(modules), do: Hardware.config_fingerprint([], [], modules, [])

  test "display settings that never reach the device do not change the fingerprint" do
    base = fingerprint([display()])

    for change <- [
          %{orientation: :rotated_180},
          %{has_dot: true},
          %{align_right: false},
          %{min_value: 5.0},
          %{display_type: :seven_segment}
        ] do
      assert base == fingerprint([display(change)]), "#{inspect(change)} must be ignored"
    end

    assert base == fingerprint([%{display() | name: "Renamed"}])
  end

  test "brightness, digit count and address change the fingerprint" do
    base = fingerprint([display()])
    refute base == fingerprint([display(%{brightness: 3})])
    refute base == fingerprint([display(%{num_digits: 8})])
    refute base == fingerprint([%{display() | i2c_address: 0x71}])
  end

  test "fingerprint is stable across VMs: term_to_binary is deterministic" do
    term = {[], [], [{:ht16k33, 0x70, 8, 4}], []}
    bytes = :erlang.term_to_binary(term, [:deterministic])
    expected = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
    assert fingerprint([display()]) == expected
  end

  describe "fingerprint stability and chip fields" do
    alias Trenino.Hardware.ADS1115.Params, as: ADSParams
    alias Trenino.Hardware.Input
    alias Trenino.Hardware.MCP23017.Params, as: MCPParams
    alias Trenino.Hardware.StepperAxis

    test "fingerprint of a config with no input chips is unchanged" do
      inputs = [
        %Input{pin: 5, input_type: :analog, sensitivity: 5, debounce: nil},
        %Input{pin: 7, input_type: :button, sensitivity: nil, debounce: 20}
      ]

      matrix = %{row_pins: [%{pin: 2}, %{pin: 3}], col_pins: [%{pin: 4}, %{pin: 6}]}
      axes = [%StepperAxis{axis_index: 0}]

      # Computed from the code before input chips were added.
      assert Hardware.config_fingerprint(inputs, [matrix], [display()], axes) ==
               "ca84ebc2aec5eaa415e1ebc0cb48628998cf9947c685668bdeddc8b143781288"
    end

    defp mcp(params \\ %{}) do
      %I2cModule{
        module_chip: :mcp23017,
        i2c_address: 0x20,
        params:
          struct(
            MCPParams,
            Map.merge(
              %{
                direct_base: 0,
                matrix_base: 8,
                debounce: 3,
                direct_mask: 1,
                row_mask: 0,
                col_mask: 0
              },
              params
            )
          )
      }
    end

    defp ads(params \\ %{}, sensitivities \\ [{0, 5}]) do
      %I2cModule{
        module_chip: :ads1115,
        i2c_address: 0x48,
        params:
          struct(
            ADSParams,
            Map.merge(%{pin_base: 0, channel_mask: 0b0011, gain: 0, ref_channel: nil}, params)
          ),
        inputs: for({ch, s} <- sensitivities, do: %Input{i2c_channel: ch, sensitivity: s})
      }
    end

    test "changing masks, debounce, gain, reference or ADS sensitivity changes the fingerprint" do
      base_mcp = fingerprint([mcp()])

      for change <- [
            %{direct_mask: 3},
            %{row_mask: 4},
            %{col_mask: 8},
            %{debounce: 5},
            %{direct_base: 1},
            %{matrix_base: 9}
          ] do
        refute base_mcp == fingerprint([mcp(change)]), "#{inspect(change)} must matter"
      end

      base_ads = fingerprint([ads()])

      for change <- [%{channel_mask: 0b0111}, %{gain: 2}, %{ref_channel: 3}, %{pin_base: 4}] do
        refute base_ads == fingerprint([ads(change)]), "#{inspect(change)} must matter"
      end

      refute base_ads == fingerprint([ads(%{}, [{0, 6}])])
      refute base_ads == fingerprint([ads(%{}, [{0, 5}, {1, 5}])])
    end
  end

  describe "config_status/2" do
    test "a device that never confirmed a fingerprint is unknown, not unapplied" do
      assert Hardware.config_status(%Device{applied_fingerprint: nil}, "abc") == :unknown
    end

    test "compares against the confirmed fingerprint otherwise" do
      assert Hardware.config_status(%Device{applied_fingerprint: "abc"}, "abc") == :applied
      assert Hardware.config_status(%Device{applied_fingerprint: "abc"}, "def") == :unapplied
    end
  end
end
