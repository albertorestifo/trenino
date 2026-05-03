defmodule Trenino.Settings.SimulatorTest do
  use ExUnit.Case, async: true

  alias Trenino.Settings.Simulator

  describe "windows?/0" do
    test "returns a boolean" do
      assert is_boolean(Simulator.windows?())
    end
  end

  describe "read_from_file/0 (non-Windows)" do
    test "returns :not_windows on non-Windows platforms" do
      unless Simulator.windows?() do
        assert {:error, :not_windows} = Simulator.read_from_file()
      end
    end
  end
end
