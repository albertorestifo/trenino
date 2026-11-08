defmodule Trenino.GaugeFixtures do
  @moduledoc "Gauges, dials and train gauge bindings for tests."

  alias Trenino.Hardware
  alias Trenino.Hardware.Gauge

  @doc """
  A VID6606 gauge on channel A of the train-lever gauge board (`[8, 7, 6, 255]`),
  3780 steps of travel. `attrs` override any field.
  """
  @spec gauge_fixture(integer(), map()) :: Gauge.t()
  def gauge_fixture(device_id, attrs \\ %{}) do
    {:ok, gauge} =
      Hardware.create_gauge(
        device_id,
        Map.merge(%{name: "Speedometer", pins: [8, 7, 6, 255]}, attrs)
      )

    gauge
  end

  @doc "A gauge with a reviewed dial: value 0 at step 0, value 100 at step 1890."
  @spec calibrated_gauge_fixture(integer(), map()) :: Gauge.t()
  def calibrated_gauge_fixture(device_id, attrs \\ %{}) do
    gauge = gauge_fixture(device_id, attrs)

    {:ok, _} =
      Hardware.save_dial_calibration(gauge, %{
        points: [%{value: 0, position: 0}, %{value: 100, position: 1890}],
        reviewed: true
      })

    {:ok, gauge} = Hardware.get_gauge(gauge.id)
    gauge
  end
end
