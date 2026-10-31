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
