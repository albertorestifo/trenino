defmodule Trenino.Train.GaugeMapperTest do
  use ExUnit.Case, async: true
  alias Trenino.Hardware.{DialCalibration, DialPoint, Gauge}
  alias Trenino.Train.{GaugeBinding, GaugeMapper}

  defp calibration(extra \\ []) do
    struct(
      %DialCalibration{
        valid: true,
        output_unit: :raw,
        points: [
          %DialPoint{value: 0.0, position: 0},
          %DialPoint{value: 50.0, position: 350},
          %DialPoint{value: 100.0, position: 720}
        ]
      },
      extra
    )
  end

  defp gauge(extra \\ [], fields \\ []),
    do: struct(%Gauge{travel: 3780, dial_calibration: calibration(extra)}, fields)

  defp gauge_binding, do: %GaugeBinding{}

  test "piecewise calibration, clamp and unit conversion" do
    gauge = gauge()
    assert {:ok, %{target: 175}} = GaugeMapper.map(gauge_binding(), 25, gauge)
    assert {:ok, %{target: 535}} = GaugeMapper.map(gauge_binding(), 75, gauge)
    assert {:ok, %{target: 720, clamped: true}} = GaugeMapper.map(gauge_binding(), 101, gauge)
    assert {:ok, %{target: 0, clamped: true}} = GaugeMapper.map(gauge_binding(), -1, gauge)

    assert {:error, :out_of_range} =
             GaugeMapper.map(%{gauge_binding() | out_of_range: :reject}, -1, gauge)

    assert {:ok, %{target: 720, value: 100.0}} =
             GaugeMapper.map(
               %{gauge_binding() | input_unit: :mps},
               44.704,
               gauge(output_unit: :mph)
             )

    assert {:ok, 10.0} = GaugeMapper.convert(36, :kmh, :mps)
    assert {:error, _} = GaugeMapper.convert(3, :raw, :mph)
  end

  test "same-unit conversion is the identity so boundary samples stay exact" do
    for unit <- [:mps, :kmh, :mph], n <- [29, 3, 29.0, 0.1, 123.456] do
      assert {:ok, n * 1.0} == GaugeMapper.convert(n, unit, unit)
    end

    points = [%DialPoint{value: 0.0, position: 0}, %DialPoint{value: 29.0, position: 500}]
    b = %{gauge_binding() | input_unit: :kmh, out_of_range: :reject}

    assert {:ok, %{target: 500, clamped: false}} =
             GaugeMapper.map(b, 29, gauge(output_unit: :kmh, points: points))
  end

  test "the dial comes from the gauge: no or invalid calibration never maps" do
    assert {:error, :invalid_calibration_or_limits} =
             GaugeMapper.map(gauge_binding(), 25, %Gauge{travel: 3780})

    assert {:error, :invalid_calibration_or_limits} =
             GaugeMapper.map(gauge_binding(), 25, %Gauge{travel: 3780, dial_calibration: nil})

    assert {:error, :invalid_calibration_or_limits} =
             GaugeMapper.map(gauge_binding(), 25, gauge(valid: false))
  end

  test "targets stay inside the gauge's travel" do
    # A dial point past a shortened travel cannot drive the needle into the end stop.
    short = gauge([], travel: 500)
    assert {:ok, %{target: 175}} = GaugeMapper.map(gauge_binding(), 25, short)
    assert {:error, :invalid_calibration_or_limits} = GaugeMapper.map(gauge_binding(), 100, short)

    assert {:ok, %{target: 720}} = GaugeMapper.map(gauge_binding(), 100, gauge([], travel: 720))
  end

  test "dial_target previews a calibration in dial units" do
    assert {:ok, %{target: 175, clamped: false}} =
             GaugeMapper.dial_target(calibration(), 25, :clamp)

    assert {:ok, %{target: 720, clamped: true}} =
             GaugeMapper.dial_target(calibration(), 500, :clamp)

    assert {:error, :out_of_range} = GaugeMapper.dial_target(calibration(), 500, :reject)
    assert {:error, _} = GaugeMapper.dial_target(calibration(), "x", :clamp)
  end

  test "invalid samples never become zero and abs is explicit" do
    for value <- [nil, true, "12", %{}, []],
        do: assert({:error, _} = GaugeMapper.map(gauge_binding(), value, gauge()))

    assert {:ok, %{target: 175}} =
             GaugeMapper.map(%{gauge_binding() | absolute_value: true}, -25, gauge())

    assert {:ok, %{value: 51.0}} =
             GaugeMapper.map(%{gauge_binding() | multiplier: 2.0, offset: 1.0}, 25, gauge())
  end

  test "overflow is a rejected sample" do
    assert {:error, _} = GaugeMapper.convert(1.0e308, :mps, :mph)
    assert {:error, _} = GaugeMapper.map(%{gauge_binding() | multiplier: 1.0e308}, 100, gauge())
  end

  test "tiny raw-unit samples retain precision for interpolation" do
    gauge =
      gauge(points: [%DialPoint{value: 0.0, position: 0}, %DialPoint{value: 1.0, position: 720}])

    assert {:ok, %{target: 3}} = GaugeMapper.map(gauge_binding(), 0.004, gauge)
    huge = Integer.pow(10, 400)
    assert {:error, _} = GaugeMapper.convert(huge, :raw, :raw)
  end
end
