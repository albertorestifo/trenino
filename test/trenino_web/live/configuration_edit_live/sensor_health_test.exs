defmodule TreninoWeb.ConfigurationEditLive.SensorHealthTest do
  use ExUnit.Case, async: true

  alias TreninoWeb.ConfigurationEditLive.SensorHealth

  test "a sensor gets the silence window from the start of watching" do
    health = SensorHealth.new(1_000)

    assert SensorHealth.unresponsive(health, [240], 5_900) == MapSet.new()
    assert SensorHealth.unresponsive(health, [240], 6_100) == MapSet.new([240])
  end

  test "a reading restarts the window" do
    health = SensorHealth.new(0) |> SensorHealth.seen(240, 4_000)

    assert SensorHealth.unresponsive(health, [240], 8_900) == MapSet.new()
    assert SensorHealth.unresponsive(health, [240], 9_100) == MapSet.new([240])
  end

  test "a reported failure holds until the next reading" do
    health = SensorHealth.new(0) |> SensorHealth.seen(240, 100) |> SensorHealth.failed(240)

    assert SensorHealth.unresponsive(health, [240, 241], 200) == MapSet.new([240])

    health = SensorHealth.seen(health, 240, 300)
    assert SensorHealth.unresponsive(health, [240, 241], 400) == MapSet.new()
  end
end
