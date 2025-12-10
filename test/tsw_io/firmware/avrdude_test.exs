defmodule TswIo.Firmware.AvrdudeTest do
  use ExUnit.Case, async: true

  alias TswIo.Firmware.Avrdude

  describe "executable_path/0" do
    test "returns {:ok, path} when avrdude is available" do
      # This test will pass on systems with avrdude installed
      # or when running in release with bundled avrdude
      case Avrdude.executable_path() do
        {:ok, path} ->
          assert is_binary(path)
          assert String.contains?(path, "avrdude")

        {:error, :avrdude_not_found} ->
          # Expected on systems without avrdude - this is fine for CI
          :ok
      end
    end
  end

  describe "available?/0" do
    test "returns boolean" do
      result = Avrdude.available?()
      assert is_boolean(result)
    end
  end

  describe "version/0 when avrdude is available" do
    test "returns version string or unknown" do
      case Avrdude.version() do
        {:ok, version} ->
          assert is_binary(version)
          # Version could be something like "7.1" or "unknown"
          assert version != ""

        {:error, :avrdude_not_found} ->
          # Expected on systems without avrdude
          :ok
      end
    end
  end

  describe "executable_path!/0" do
    test "returns path when avrdude is available" do
      case Avrdude.executable_path() do
        {:ok, expected_path} ->
          assert Avrdude.executable_path!() == expected_path

        {:error, :avrdude_not_found} ->
          assert_raise RuntimeError, ~r/avrdude executable not found/, fn ->
            Avrdude.executable_path!()
          end
      end
    end
  end
end
