defmodule Trenino.SimulatorTest do
  use ExUnit.Case, async: true

  alias Trenino.Simulator

  describe "windows?/0" do
    test "returns a boolean" do
      result = Simulator.windows?()
      assert is_boolean(result)
    end
  end
end
