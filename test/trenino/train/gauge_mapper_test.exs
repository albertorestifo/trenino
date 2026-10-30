defmodule Trenino.Train.GaugeMapperTest do
  use ExUnit.Case, async: true
  alias Trenino.Hardware.StepperAxis
  alias Trenino.Train.{GaugeBinding, GaugeMapper, GaugePoint}

  defp gauge do
    %GaugeBinding{
      points: [
        %GaugePoint{value: 0.0, position: 0},
        %GaugePoint{value: 50.0, position: 350},
        %GaugePoint{value: 100.0, position: 720}
      ]
    }
  end

  test "piecewise calibration, clamp and unit conversion" do
    axis = %StepperAxis{}
    assert {:ok, %{target: 175}} = GaugeMapper.map(gauge(), 25, axis)
    assert {:ok, %{target: 535}} = GaugeMapper.map(gauge(), 75, axis)
    assert {:ok, %{target: 720, clamped: true}} = GaugeMapper.map(gauge(), 101, axis)
    assert {:ok, %{target: 0, clamped: true}} = GaugeMapper.map(gauge(), -1, axis)
    assert {:error, :out_of_range} = GaugeMapper.map(%{gauge() | out_of_range: :reject}, -1, axis)

    assert {:ok, %{target: 720, value: 100.0}} =
             GaugeMapper.map(%{gauge() | input_unit: :mps, output_unit: :mph}, 44.704, axis)

    assert {:ok, 10.0} = GaugeMapper.convert(36, :kmh, :mps)
    assert {:error, _} = GaugeMapper.convert(3, :raw, :mph)
  end

  test "invalid samples never become zero and abs is explicit" do
    for value <- [nil, true, "12", %{}, []],
        do: assert({:error, _} = GaugeMapper.map(gauge(), value, %StepperAxis{}))

    assert {:ok, %{target: 175}} =
             GaugeMapper.map(%{gauge() | absolute_value: true}, -25, %StepperAxis{})

    assert {:ok, %{value: 51.0}} =
             GaugeMapper.map(%{gauge() | multiplier: 2.0, offset: 1.0}, 25, %StepperAxis{})
  end

  test "overflow is a rejected sample" do
    assert {:error, _} = GaugeMapper.convert(1.0e308, :mps, :mph)
    assert {:error, _} = GaugeMapper.map(%{gauge() | multiplier: 1.0e308}, 100, %StepperAxis{})
  end

  test "tiny raw-unit samples retain precision for interpolation" do
    b = %{
      gauge()
      | points: [%GaugePoint{value: 0.0, position: 0}, %GaugePoint{value: 1.0, position: 720}]
    }

    assert {:ok, %{target: 3}} = GaugeMapper.map(b, 0.004, %StepperAxis{})
    huge = Integer.pow(10, 400)
    assert {:error, _} = GaugeMapper.convert(huge, :raw, :raw)
  end
end
