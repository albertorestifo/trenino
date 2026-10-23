defmodule Trenino.Serial.TestIsolationTest do
  use Trenino.SerialSafetyCase, async: false

  alias Trenino.Serial.Connection

  setup :set_mimic_global

  test "global hardware guards have no application-owned serial discovery process" do
    # A surviving Connection schedules discovery outside the owning test and
    # repeatedly crashes under the next test's global forbidden UART stub.
    assert Process.whereis(Connection) == nil

    assert_raise RuntimeError, ~r/Real Circuits.UART.enumerate\/0/, fn ->
      Circuits.UART.enumerate()
    end

    assert Process.alive?(Process.whereis(Trenino.Repo))
    assert Process.alive?(Process.whereis(Trenino.Registry))
  end
end
