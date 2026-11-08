defmodule Trenino.LeverSweepFixtures do
  @moduledoc """
  Real lever sweeps recorded from Train Sim World on 2026-11-08.

  Each sweep pushed every target input several times (so gates engage),
  then read the actual input, output and notch index. Every expected notch
  table here was confirmed by a driver against the in-game lever.

  Long linear runs (1116 power, AC4400 dynamic brake and service range) are
  generated from the recorded straight line between their recorded ends;
  gates, snaps and boundaries are the recorded rows.

  Rows are `{set_input, actual_input, output, notch_index}`, rounded to 2 places
  like `Trenino.Simulator.Client.get_float/2`.
  """

  alias Trenino.Simulator.LeverAnalyzer.Sample

  @doc "Converts recorded rows to analyzer samples."
  @spec samples([{number(), number(), number(), integer()}]) :: [Sample.t()]
  def samples(rows) do
    Enum.map(rows, fn {set, actual, output, idx} ->
      %Sample{
        set_input: Float.round(set * 1.0, 2),
        actual_input: Float.round(actual * 1.0, 2),
        output: Float.round(output * 1.0, 2),
        notch_index: idx,
        snapped: abs(actual - set) > 0.01
      }
    end)
  end

  @doc """
  DB BR430 MasterController (input 0..1, output -11..10).

  Confirmed: Emergency gate, Brake linear (-10 to -0.91), Off gate, Power linear (1 to 10).
  The sweep stopped at input 0.85 because of a speed guard; power is linear to 1.0.
  """
  def br430_master_controller do
    [
      {0.0, 0.0, -11.0, 0},
      {0.025, 0.0, -11.0, 0},
      {0.05, 0.099, -10.0, 1},
      {0.075, 0.099, -10.0, 1},
      {0.1, 0.1, -10.0, 1},
      {0.125, 0.125, -9.252, 2},
      {0.15, 0.15, -8.505, 2},
      {0.175, 0.175, -7.757, 2},
      {0.2, 0.2, -7.01, 2},
      {0.225, 0.225, -6.262, 2},
      {0.25, 0.25, -5.515, 2},
      {0.275, 0.275, -4.767, 2},
      {0.3, 0.3, -4.02, 2},
      {0.325, 0.325, -3.272, 2},
      {0.35, 0.35, -2.525, 2},
      {0.375, 0.375, -1.777, 2},
      {0.4, 0.4, -1.03, 2},
      {0.425, 0.41, -0.909, 3},
      {0.45, 0.41, -0.909, 3},
      {0.475, 0.5, 0.0, 4},
      {0.5, 0.5, 0.0, 4},
      {0.525, 0.5, 0.0, 4},
      {0.55, 0.59, 1.0, 5},
      {0.575, 0.59, 1.0, 5},
      {0.6, 0.6, 1.22, 6},
      {0.625, 0.625, 1.768, 6},
      {0.65, 0.65, 2.317, 6},
      {0.675, 0.675, 2.866, 6},
      {0.7, 0.7, 3.415, 6},
      {0.725, 0.725, 3.963, 6},
      {0.75, 0.75, 4.512, 6},
      {0.775, 0.775, 5.061, 6},
      {0.8, 0.8, 5.61, 6},
      {0.825, 0.825, 6.159, 6},
      {0.85, 0.85, 6.707, 6}
    ]
  end

  @doc """
  LIRR M9 MasterController (input 0..1, output -2..1).

  Confirmed: Emergency gate, Brake linear (-1 to -0.25), Coast gate, Power linear (0.25 to 1).
  """
  def m9_master_controller do
    [
      {0.0, 0.0, -2.0, 0},
      {0.025, 0.0, -2.0, 0},
      {0.05, 0.1, -1.0, 1},
      {0.075, 0.1, -1.0, 1},
      {0.1, 0.1, -1.0, 1},
      {0.125, 0.125, -0.94, 2},
      {0.15, 0.15, -0.87, 2},
      {0.175, 0.175, -0.81, 2},
      {0.2, 0.2, -0.75, 2},
      {0.225, 0.225, -0.69, 2},
      {0.25, 0.25, -0.62, 2},
      {0.275, 0.275, -0.56, 2},
      {0.3, 0.3, -0.5, 2},
      {0.325, 0.325, -0.44, 2},
      {0.35, 0.35, -0.37, 2},
      {0.375, 0.375, -0.31, 2},
      {0.4, 0.4, -0.25, 3},
      {0.425, 0.4, -0.25, 3},
      {0.45, 0.4, -0.25, 3},
      {0.475, 0.5, 0.0, 4},
      {0.5, 0.5, 0.0, 4},
      {0.525, 0.5, 0.0, 4},
      {0.55, 0.6, 0.25, 5},
      {0.575, 0.6, 0.25, 5},
      {0.6, 0.6, 0.25, 5},
      {0.625, 0.625, 0.3, 6},
      {0.65, 0.65, 0.34, 6},
      {0.675, 0.675, 0.39, 6},
      {0.7, 0.7, 0.44, 6},
      {0.725, 0.725, 0.48, 6},
      {0.75, 0.75, 0.53, 6},
      {0.775, 0.775, 0.58, 6},
      {0.8, 0.8, 0.63, 6},
      {0.825, 0.825, 0.67, 6},
      {0.85, 0.85, 0.72, 6},
      {0.875, 0.875, 0.77, 6},
      {0.9, 0.9, 0.81, 6},
      {0.925, 0.925, 0.86, 6},
      {0.95, 0.95, 0.91, 6},
      {0.975, 0.975, 0.95, 6},
      {1.0, 1.0, 1.0, 6}
    ]
  end

  @doc """
  ÖBB 1116 Throttle_F (input 0..1, output -1..1).

  Confirmed: Off gate, Power linear (0 to 1).
  """
  def obb1116_throttle do
    linear =
      for i <- 5..39 do
        input = Float.round(i * 0.025, 3)
        {input, input, Float.round((input - 0.1) / 0.9, 3), 2}
      end

    [
      {0.0, 0.0, -1.0, 0},
      {0.025, 0.0, -1.0, 0},
      {0.05, 0.1, 0.0, 1},
      {0.075, 0.1, 0.0, 1},
      {0.1, 0.1, 0.0, 1}
    ] ++ linear ++ [{1.0, 1.0, 1.0, 3}]
  end

  @doc """
  ÖBB 1116 TrainBrake_F (input 0..1, output -1..1). Release is spring-loaded.

  Confirmed: 11 gates, Running (0.1) to Emergency (1.0), outputs 0.0 to 1.0.
  """
  def obb1116_train_brake do
    [
      {0.0, 0.1, 0.0, 0},
      {0.025, 0.1, 0.0, 0},
      {0.05, 0.1, 0.0, 0},
      {0.075, 0.1, 0.0, 0},
      {0.1, 0.1, 0.0, 0},
      {0.125, 0.1, 0.0, 0},
      {0.15, 0.2, 0.1, 1},
      {0.175, 0.2, 0.1, 1},
      {0.2, 0.2, 0.1, 1},
      {0.225, 0.2, 0.1, 1},
      {0.25, 0.275, 0.2, 2},
      {0.275, 0.275, 0.2, 2},
      {0.3, 0.275, 0.2, 2},
      {0.325, 0.35, 0.3, 3},
      {0.35, 0.35, 0.3, 3},
      {0.375, 0.35, 0.3, 3},
      {0.4, 0.425, 0.4, 4},
      {0.425, 0.425, 0.4, 4},
      {0.45, 0.425, 0.4, 4},
      {0.475, 0.5, 0.5, 5},
      {0.5, 0.5, 0.5, 5},
      {0.525, 0.5, 0.5, 5},
      {0.55, 0.575, 0.6, 6},
      {0.575, 0.575, 0.6, 6},
      {0.6, 0.575, 0.6, 6},
      {0.625, 0.65, 0.7, 7},
      {0.65, 0.65, 0.7, 7},
      {0.675, 0.65, 0.7, 7},
      {0.7, 0.725, 0.8, 8},
      {0.725, 0.725, 0.8, 8},
      {0.75, 0.725, 0.8, 8},
      {0.775, 0.8, 0.9, 9},
      {0.8, 0.8, 0.9, 9},
      {0.825, 0.8, 0.9, 9},
      {0.85, 0.8, 0.9, 9},
      {0.875, 0.8, 0.9, 9},
      {0.9, 0.8, 0.9, 9},
      {0.925, 1.0, 1.0, 10},
      {0.95, 1.0, 1.0, 10},
      {0.975, 1.0, 1.0, 10},
      {1.0, 1.0, 1.0, 10}
    ]
  end

  @doc """
  GE AC4400CW ThrottleAndBrake (input -1..1, output -9..8).

  Confirmed: Dynamic brake linear (-9 to -2), Set-up gate (-1), Idle gate (0),
  Run 1-8 gates (1 to 8).
  """
  def ac4400_throttle_and_brake do
    dynamic =
      for i <- 0..28 do
        input = Float.round(-1.0 + i * 0.025, 3)
        {input, input, Float.round(-9.0 + i * 0.25, 3), 0}
      end

    dynamic ++
      [
        {-0.275, -0.3, -2.0, 0},
        {-0.25, -0.2, -1.0, 1},
        {-0.225, -0.2, -1.0, 1},
        {-0.2, -0.2, -1.0, 1},
        {-0.175, -0.2, -1.0, 1},
        {-0.15, -0.2, -1.0, 1},
        {-0.125, -0.2, -1.0, 1},
        {-0.1, -0.2, -1.0, 1},
        {-0.075, -0.2, -1.0, 1},
        {-0.05, -0.2, -1.0, 1},
        {-0.025, -0.2, -1.0, 1},
        {0.0, 0.2, 0.0, 2},
        {0.025, 0.2, 0.0, 2},
        {0.05, 0.2, 0.0, 2},
        {0.075, 0.2, 0.0, 2},
        {0.1, 0.2, 0.0, 2},
        {0.125, 0.2, 0.0, 2},
        {0.15, 0.2, 0.0, 2},
        {0.175, 0.2, 0.0, 2},
        {0.2, 0.2, 0.0, 2},
        {0.225, 0.2, 0.0, 2},
        {0.25, 0.2, 0.0, 2},
        {0.275, 0.3, 1.0, 3},
        {0.3, 0.3, 1.0, 3},
        {0.325, 0.3, 1.0, 3},
        {0.35, 0.3, 1.0, 3},
        {0.375, 0.4, 2.0, 4},
        {0.4, 0.4, 2.0, 4},
        {0.425, 0.4, 2.0, 4},
        {0.45, 0.4, 2.0, 4},
        {0.475, 0.5, 3.0, 5},
        {0.5, 0.5, 3.0, 5},
        {0.525, 0.5, 3.0, 5},
        {0.55, 0.6, 4.0, 6},
        {0.575, 0.6, 4.0, 6},
        {0.6, 0.6, 4.0, 6},
        {0.625, 0.6, 4.0, 6},
        {0.65, 0.6, 4.0, 6},
        {0.675, 0.7, 5.0, 7},
        {0.7, 0.7, 5.0, 7},
        {0.725, 0.7, 5.0, 7},
        {0.75, 0.8, 6.0, 8},
        {0.775, 0.8, 6.0, 8},
        {0.8, 0.8, 6.0, 8},
        {0.825, 0.8, 6.0, 8},
        {0.85, 0.9, 7.0, 9},
        {0.875, 0.9, 7.0, 9},
        {0.9, 0.9, 7.0, 9},
        {0.925, 0.9, 7.0, 9},
        {0.95, 1.0, 8.0, 10},
        {0.975, 1.0, 8.0, 10},
        {1.0, 1.0, 8.0, 10}
      ]
  end

  @doc """
  GE AC4400CW AutomaticBrake (input 0..1, output -1..4).

  Confirmed: Release gate (-1), Service linear (0 to 1, Minimum Reduction to
  Full Service), Suppression gate (2), Handle Off gate (3), Emergency gate (4).
  """
  def ac4400_automatic_brake do
    service =
      for i <- 9..24 do
        input = Float.round(i * 0.025, 3)
        {input, input, Float.round((input - 0.2) / 0.4, 3), 2}
      end

    [
      {0.0, 0.0, -1.0, 0},
      {0.025, 0.0, -1.0, 0},
      {0.05, 0.0, -1.0, 0},
      {0.075, 0.0, -1.0, 0},
      {0.1, 0.2, 0.0, 1},
      {0.125, 0.2, 0.0, 1},
      {0.15, 0.2, 0.0, 1},
      {0.175, 0.2, 0.0, 1},
      {0.2, 0.2, 0.0, 1}
    ] ++
      service ++
      [
        {0.625, 0.65, 1.0, 3},
        {0.65, 0.65, 1.0, 3},
        {0.675, 0.7, 2.0, 4},
        {0.7, 0.7, 2.0, 4},
        {0.725, 0.7, 2.0, 4},
        {0.75, 0.8, 3.0, 5},
        {0.775, 0.8, 3.0, 5},
        {0.8, 0.8, 3.0, 5},
        {0.825, 0.8, 3.0, 5},
        {0.85, 0.8, 3.0, 5},
        {0.875, 0.8, 3.0, 5},
        {0.9, 0.8, 3.0, 5},
        {0.925, 1.0, 4.0, 6},
        {0.95, 1.0, 4.0, 6},
        {0.975, 1.0, 4.0, 6},
        {1.0, 1.0, 4.0, 6}
      ]
  end

  @doc """
  Raw `Property.DisplayInfo` label rows `{value_source, min, max, display_name}`
  recorded from the simulator for the levers above.
  """
  def labels(:br430_master_controller) do
    [
      {"Output", -11.5, -10.5, "Emergency Brake"},
      {"Output", -10.5, -1.01, "{BrakePercent} Brake"},
      {"Output", -1.0, -0.3, "Min Brake"},
      {"Output", -0.29, 0.29, "0"},
      {"Output", 0.3, 1.0, "Min Power"},
      {"Output", 1.01, 10.5, "{PowerPercent} Power"}
    ]
  end

  def labels(:m9_master_controller) do
    [
      {"Output", -2.5, -1.5, "Emergency"},
      {"Output", -1.5, -0.995, "Max Brake"},
      {"Output", -0.995, -0.255, "Brake {Brake}"},
      {"Output", -0.255, -0.1, "Min Brake"},
      {"Output", -0.1, 0.1, "Coast"},
      {"Output", 0.1, 0.255, "Min Power"},
      {"Output", 0.255, 0.995, "Power {Power}"},
      {"Output", 0.995, 1.0, "Max Power"}
    ]
  end

  def labels(:obb1116_throttle) do
    [
      {"Input", -0.05, 0.05, "Off"},
      {"Input", 0.05, 0.105, "Min"},
      {"Input", 0.105, 0.995, "{Power}"},
      {"Input", 0.995, 1.01, "Max"}
    ]
  end

  def labels(:obb1116_train_brake) do
    [
      {"Input", -0.5, 0.05, "Release"},
      {"Input", 0.05, 0.15, "Running"},
      {"Input", 0.15, 0.237, "1A"},
      {"Input", 0.237, 0.312, "1B"},
      {"Input", 0.312, 0.387, "2"},
      {"Input", 0.387, 0.463, "3"},
      {"Input", 0.463, 0.538, "4"},
      {"Input", 0.538, 0.613, "5"},
      {"Input", 0.613, 0.688, "6"},
      {"Input", 0.688, 0.762, "7"},
      {"Input", 0.762, 0.9, "Full Service"},
      {"Input", 0.9, 1.5, "Emergency"}
    ]
  end

  def labels(:ac4400_throttle_and_brake) do
    brakes = for n <- 8..1//-1, do: {"Output", -n - 1.5, -n - 0.5, "B#{n}"}
    runs = for n <- 1..8, do: {"Output", n * 1.0, n * 1.0, "N#{n}"}
    brakes ++ [{"Output", -1.5, -0.5, "Set-up"}, {"Output", 0.0, 0.0, "Idle"}] ++ runs
  end

  def labels(:ac4400_automatic_brake) do
    [
      {"Output", -1.5, -0.75, "Release"},
      {"Output", -0.751, 0.0, "Minimum Reduction"},
      {"Output", 0.0, 1.0, "Service {%}"},
      {"Output", 1.0, 1.5, "Full Service"},
      {"Output", 1.5, 2.5, "Suppression"},
      {"Output", 2.5, 3.5, "Handle Off"},
      {"Output", 3.5, 4.5, "Emergency"}
    ]
  end

  def labels(:class802_power_side) do
    [
      {"Output", -0.125, 0.5, "Off"},
      {"Output", 0.5, 4.5, "{PowerNumber}"}
    ]
  end

  @doc """
  GWR Class 802 PowerHandle, Off and power side (input 0..1 of -1..1, output 0..4).

  Power is a single sim notch (index 5) whose output steps 1-4 while the input
  moves freely. Confirmed: Off gate, then Power 1-4 as four separate gates.
  """
  def class802_power_side do
    [
      {0.0, 0.0, 0.0, 4},
      {0.05, 0.0, 0.0, 4},
      {0.1, 0.0, 0.0, 4},
      {0.15, 0.25, 1.0, 5},
      {0.2, 0.25, 1.0, 5},
      {0.25, 0.25, 1.0, 5},
      {0.3, 0.3, 1.0, 5},
      {0.35, 0.35, 1.0, 5},
      {0.4, 0.4, 2.0, 5},
      {0.45, 0.45, 2.0, 5},
      {0.5, 0.5, 2.0, 5},
      {0.55, 0.55, 2.0, 5},
      {0.6, 0.6, 2.0, 5},
      {0.65, 0.65, 3.0, 5},
      {0.7, 0.7, 3.0, 5},
      {0.75, 0.75, 3.0, 5},
      {0.8, 0.8, 3.0, 5},
      {0.85, 0.85, 3.0, 5},
      {0.9, 0.9, 4.0, 5},
      {0.95, 0.95, 4.0, 5},
      {1.0, 1.0, 4.0, 5}
    ]
  end
end
