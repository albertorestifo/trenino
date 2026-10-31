defmodule Trenino.Train.GaugeMapperTest do
  use ExUnit.Case, async: true
  alias Trenino.Hardware.{DialCalibration, DialPoint, StepperAxis}
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

  defp axis(extra \\ []), do: %StepperAxis{dial_calibration: calibration(extra)}
  defp gauge, do: %GaugeBinding{}

  test "piecewise calibration, clamp and unit conversion" do
    axis = axis()
    assert {:ok, %{target: 175}} = GaugeMapper.map(gauge(), 25, axis)
    assert {:ok, %{target: 535}} = GaugeMapper.map(gauge(), 75, axis)
    assert {:ok, %{target: 720, clamped: true}} = GaugeMapper.map(gauge(), 101, axis)
    assert {:ok, %{target: 0, clamped: true}} = GaugeMapper.map(gauge(), -1, axis)
    assert {:error, :out_of_range} = GaugeMapper.map(%{gauge() | out_of_range: :reject}, -1, axis)

    assert {:ok, %{target: 720, value: 100.0}} =
             GaugeMapper.map(%{gauge() | input_unit: :mps}, 44.704, axis(output_unit: :mph))

    assert {:ok, 10.0} = GaugeMapper.convert(36, :kmh, :mps)
    assert {:error, _} = GaugeMapper.convert(3, :raw, :mph)
  end

  test "the dial comes from the axis: no or invalid calibration never maps" do
    assert {:error, :invalid_calibration_or_limits} = GaugeMapper.map(gauge(), 25, %StepperAxis{})

    assert {:error, :invalid_calibration_or_limits} =
             GaugeMapper.map(gauge(), 25, axis(valid: false))
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
        do: assert({:error, _} = GaugeMapper.map(gauge(), value, axis()))

    assert {:ok, %{target: 175}} =
             GaugeMapper.map(%{gauge() | absolute_value: true}, -25, axis())

    assert {:ok, %{value: 51.0}} =
             GaugeMapper.map(%{gauge() | multiplier: 2.0, offset: 1.0}, 25, axis())
  end

  test "overflow is a rejected sample" do
    assert {:error, _} = GaugeMapper.convert(1.0e308, :mps, :mph)
    assert {:error, _} = GaugeMapper.map(%{gauge() | multiplier: 1.0e308}, 100, axis())
  end

  test "tiny raw-unit samples retain precision for interpolation" do
    axis =
      axis(points: [%DialPoint{value: 0.0, position: 0}, %DialPoint{value: 1.0, position: 720}])

    assert {:ok, %{target: 3}} = GaugeMapper.map(gauge(), 0.004, axis)
    huge = Integer.pow(10, 400)
    assert {:error, _} = GaugeMapper.convert(huge, :raw, :raw)
  end
end
