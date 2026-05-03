defmodule Trenino.Firmware.CompatibilityTest do
  use ExUnit.Case, async: false

  alias Trenino.Firmware.Compatibility
  alias Trenino.Firmware.FirmwareRelease

  setup do
    original = Application.get_env(:trenino, :firmware_version_requirement)

    on_exit(fn ->
      if is_nil(original) do
        Application.delete_env(:trenino, :firmware_version_requirement)
      else
        Application.put_env(:trenino, :firmware_version_requirement, original)
      end
    end)

    :ok
  end

  defp set_requirement(value) do
    if is_nil(value) do
      Application.delete_env(:trenino, :firmware_version_requirement)
    else
      Application.put_env(:trenino, :firmware_version_requirement, value)
    end
  end

  describe "requirement/0" do
    test "returns nil when unset" do
      set_requirement(nil)
      assert Compatibility.requirement() == nil
    end

    test "returns a parsed Version.Requirement when set" do
      set_requirement("~> 1.0")
      assert %Version.Requirement{} = Compatibility.requirement()
    end

    test "raises on invalid requirement string" do
      set_requirement("not a requirement")
      assert_raise Version.InvalidRequirementError, fn -> Compatibility.requirement() end
    end
  end

  describe "compatible?/1 with no requirement set" do
    setup do
      set_requirement(nil)
      :ok
    end

    test "returns true for any well-formed version" do
      assert Compatibility.compatible?("1.0.0")
      assert Compatibility.compatible?("99.0.0")
    end

    test "returns true for a release struct" do
      assert Compatibility.compatible?(%FirmwareRelease{version: "1.0.0"})
    end

    test "returns false for an unparseable version (still safer than installing junk)" do
      refute Compatibility.compatible?("not-a-version")
    end
  end

  describe "compatible?/1 with a range requirement" do
    setup do
      set_requirement(">= 1.0.0 and < 2.0.0")
      :ok
    end

    test "true for versions inside the range" do
      assert Compatibility.compatible?("1.0.0")
      assert Compatibility.compatible?("1.5.3")
      assert Compatibility.compatible?("1.99.99")
    end

    test "false for versions below the range" do
      refute Compatibility.compatible?("0.9.9")
    end

    test "false for versions at or above the upper bound" do
      refute Compatibility.compatible?("2.0.0")
      refute Compatibility.compatible?("3.1.0")
    end

    test "strips a leading 'v' from the version string" do
      assert Compatibility.compatible?("v1.2.3")
      refute Compatibility.compatible?("v2.0.0")
    end

    test "accepts a FirmwareRelease struct" do
      assert Compatibility.compatible?(%FirmwareRelease{version: "1.4.0"})
      refute Compatibility.compatible?(%FirmwareRelease{version: "2.0.0"})
    end

    test "false for unparseable version strings" do
      refute Compatibility.compatible?("garbage")
      refute Compatibility.compatible?("1.2")
      refute Compatibility.compatible?(nil)
    end

    test "false for a release whose version is nil" do
      refute Compatibility.compatible?(%FirmwareRelease{version: nil})
    end

    test "pre-releases do not match a plain range by default" do
      refute Compatibility.compatible?("1.5.0-rc1")
    end
  end

  describe "compatible?/1 with a tilde requirement" do
    setup do
      set_requirement("~> 1.2")
      :ok
    end

    test "matches versions in the same major" do
      assert Compatibility.compatible?("1.2.0")
      assert Compatibility.compatible?("1.99.0")
    end

    test "rejects versions in the next major" do
      refute Compatibility.compatible?("2.0.0")
    end
  end
end
