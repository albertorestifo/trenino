defmodule Trenino.Train.NotchDesignTest do
  use ExUnit.Case, async: true

  alias Trenino.LeverSweepFixtures, as: Fixtures
  alias Trenino.Simulator.LeverAnalyzer
  alias Trenino.Simulator.LeverMetadata
  alias Trenino.Train.{Notch, NotchDesign}

  # Runs a recorded sweep through the analyzer and returns the notches
  # calibration would save, so the designs follow the confirmed tables.
  defp notches(fixture, opts \\ []) do
    raw = %{
      "namedValues" =>
        Enum.map(Fixtures.labels(fixture), fn {source, min, max, name} ->
          %{
            "valueSource" => source,
            "valueRange" => %{"min" => min, "max" => max},
            "displayName" => name,
            "bDisplayNameIsFormatString" => String.contains?(name, "{")
          }
        end)
    }

    metadata =
      struct!(
        %LeverMetadata{
          control_path: "CurrentDrivableActor/Test",
          labels: LeverMetadata.parse_labels(raw)
        },
        Keyword.get(opts, :metadata, [])
      )

    {:ok, result} =
      Fixtures
      |> apply(fixture, [])
      |> Fixtures.samples()
      |> LeverAnalyzer.analyze_samples(
        sweep_step: Keyword.get(opts, :sweep_step, 0.025),
        metadata: metadata
      )

    result.suggested_notches
    |> Enum.with_index()
    |> Enum.map(fn {n, index} ->
      %Notch{
        index: index,
        type: n.type,
        value: n[:value],
        min_value: n[:min_value],
        max_value: n[:max_value],
        sim_input_min: n.input_min,
        sim_input_max: n.input_max,
        description: n.description
      }
    end)
  end

  defp design!(notches, name \\ nil) do
    {:ok, design} = NotchDesign.from_notches(notches, name)
    design
  end

  defp gate(index, description, value, at),
    do: %Notch{
      index: index,
      type: :gate,
      value: value,
      description: description,
      sim_input_min: at,
      sim_input_max: at
    }

  defp band(index, description, value, {from, to}),
    do: %Notch{
      index: index,
      type: :gate,
      value: value,
      description: description,
      sim_input_min: from,
      sim_input_max: to
    }

  defp linear(index, description, {min, max}, {from, to}),
    do: %Notch{
      index: index,
      type: :linear,
      min_value: min,
      max_value: max,
      description: description,
      sim_input_min: from,
      sim_input_max: to
    }

  describe "from_notches/2 on recorded levers" do
    test "BR430: the zero gate is centred, ranges get two positions, Power gets an end stop" do
      design = design!(notches(:br430_master_controller))

      assert design.positions == [
               {:deep, "Emergency Brake"},
               {:smooth, ""},
               {:smooth, ""},
               {:deep, "0"},
               {:smooth, ""},
               {:smooth, ""},
               {:standard, "Power"}
             ]
    end

    test "M9: Coast is centred like the simulator's 0.5" do
      design = design!(notches(:m9_master_controller))

      assert design.positions == [
               {:deep, "Emergency"},
               {:smooth, ""},
               {:smooth, ""},
               {:deep, "Coast"},
               {:smooth, ""},
               {:smooth, ""},
               {:standard, "Power"}
             ]
    end

    test "ÖBB 1116 throttle: a long power range keeps its share of the travel" do
      design = design!(notches(:obb1116_throttle))

      assert design.positions == [
               {:deep, "Off"},
               {:smooth, ""},
               {:smooth, ""},
               {:smooth, ""},
               {:smooth, ""},
               {:standard, "Power"}
             ]
    end

    test "ÖBB 1116 train brake: eleven gates, only Emergency is Deep" do
      meta = [input_min: 0.0, input_max: 1.0]
      design = design!(notches(:obb1116_train_brake, metadata: meta))

      assert NotchDesign.count(design) == 11
      assert NotchDesign.positions_with(design, :deep) == [11]
      assert NotchDesign.positions_with(design, :smooth) == []
      assert List.last(design.positions) == {:deep, "Emergency"}
    end

    test "AC4400 throttle: the dynamic brake range is shortened to fit 13 positions" do
      design = design!(notches(:ac4400_throttle_and_brake))

      assert NotchDesign.count(design) == 13

      assert Enum.take(design.positions, 5) == [
               {:standard, "B8 – B1"},
               {:smooth, ""},
               {:smooth, ""},
               {:standard, "Set-up"},
               {:deep, "Idle"}
             ]

      assert design.positions |> Enum.drop(5) |> Enum.map(&elem(&1, 1)) ==
               Enum.map(1..8, &"N#{&1}")
    end

    test "AC4400 automatic brake: Handle Off and Emergency are Deep, Release is Standard" do
      design = design!(notches(:ac4400_automatic_brake))

      # Suppression (0.7) and Handle Off (0.8) land near their simulator inputs
      assert design.positions == [
               {:standard, "Release"},
               {:smooth, ""},
               {:smooth, ""},
               {:smooth, ""},
               {:standard, "Suppression"},
               {:deep, "Handle Off"},
               {:deep, "Emergency"}
             ]
    end

    test "Class 802: Off is Deep, stepped power notches are Standard" do
      design = design!(notches(:class802_power_side, sweep_step: 0.05))

      assert design.positions == [
               {:deep, "Off"},
               {:standard, "Power 1"},
               {:standard, "Power 2"},
               {:standard, "Power 3"},
               {:standard, "Power 4"}
             ]
    end
  end

  describe "from_notches/2" do
    test "orders notches by index" do
      design =
        design!([gate(1, "B", 1.0, 1.0), gate(0, "A", 0.0, 0.0)])

      assert design.positions == [{:standard, "A"}, {:standard, "B"}]
    end

    test "two ranges next to each other are split by a Standard position" do
      design =
        design!([
          gate(0, "Emergency", -2.0, 0.0),
          linear(1, "Brake", {-1.0, 0.0}, {0.1, 0.5}),
          linear(2, "Power", {0.0, 1.0}, {0.5, 1.0})
        ])

      assert design.positions == [
               {:deep, "Emergency"},
               {:smooth, ""},
               {:smooth, ""},
               {:standard, ""},
               {:smooth, ""},
               {:smooth, ""},
               {:standard, "Power"}
             ]
    end

    test "Class 802 full lever: Off is the centre position, the brake range fills the rest" do
      design =
        design!([
          gate(0, "Emergency", -2.0, -1.0),
          linear(1, "Brake", {-1.0, -0.25}, {-0.9, -0.25}),
          gate(2, "Off", 0.0, 0.0),
          band(3, "Power 1", 1.0, {0.25, 0.36}),
          band(4, "Power 2", 2.0, {0.38, 0.62}),
          band(5, "Power 3", 3.0, {0.64, 0.86}),
          band(6, "Power 4", 4.0, {0.88, 1.0})
        ])

      # The generator walls the range off from Emergency, so no extra click
      assert design.positions == [
               {:deep, "Emergency"},
               {:smooth, ""},
               {:smooth, ""},
               {:smooth, ""},
               {:deep, "Off"},
               {:standard, "Power 1"},
               {:standard, "Power 2"},
               {:standard, "Power 3"},
               {:standard, "Power 4"}
             ]

      # Off at input 0.0 of -1.0..1.0 is the middle of 9 evenly spaced positions
      assert NotchDesign.positions_with(design, :deep) == [1, 5]
    end

    test "a range keeps one position when two don't fit on the disk" do
      gates = for i <- 0..10, do: gate(i + 1, "N#{i}", i * 1.0, 0.1 + i * 0.09)
      design = design!([linear(0, "Brake", {-2.0, -1.0}, {0.0, 0.05}) | gates])

      assert NotchDesign.count(design) == 13
      assert NotchDesign.positions_with(design, :smooth) == [2]
    end

    test "gates follow their simulator inputs, not their order" do
      # Mid sits at 0.75 of the travel, so the range before it takes three
      # times the room of the one after
      design =
        design!([
          gate(0, "Low", 0.0, 0.0),
          linear(1, "Ramp", {0.0, 1.0}, {0.05, 0.7}),
          gate(2, "Mid", 1.0, 0.75),
          linear(3, "Top", {1.0, 2.0}, {0.8, 0.95}),
          gate(4, "High", 2.0, 1.0)
        ])

      mid = Enum.find_index(design.positions, &(&1 == {:standard, "Mid"}))
      assert_in_delta mid / (NotchDesign.count(design) - 1), 0.75, 0.05
    end

    test "a range without simulator inputs gets two Smooth positions" do
      design =
        design!([
          %Notch{index: 0, type: :gate, value: 0.0, description: "Off"},
          %Notch{index: 1, type: :linear, min_value: 0.0, max_value: 1.0, description: "Power"}
        ])

      assert design.positions == [
               {:deep, "Off"},
               {:smooth, ""},
               {:smooth, ""},
               {:standard, "Power"}
             ]
    end

    test "a zero gate is Standard when every output is on one side" do
      design = design!([gate(0, "Notch 0", 0.0, 0.0), gate(1, "Notch 1", 1.0, 1.0)])
      assert NotchDesign.positions_with(design, :deep) == []
    end

    test "errors when the lever can't make a disk" do
      assert NotchDesign.from_notches([]) == {:error, :no_notches}
      assert NotchDesign.from_notches([gate(0, "Off", 0.0, 0.0)]) == {:error, :too_few_positions}

      many = for i <- 0..13, do: gate(i, "N#{i}", i * 1.0, i / 13)
      assert NotchDesign.from_notches(many) == {:error, :too_many_positions}
    end
  end

  describe "generator_url/1" do
    test "encodes positions, feels, labels and the name" do
      design = design!(notches(:br430_master_controller), "BR430 Master controller")
      url = NotchDesign.generator_url(design)

      assert "https://albertorestifo.github.io/train-lever-generator/?" <> query = url

      assert URI.decode_query(query) == %{
               "positions" => "7",
               "deep" => "1,4",
               "smooth" => "2,3,5,6",
               "label" => "Power",
               "name" => "BR430 Master controller"
             }

      labels =
        query
        |> String.split("&")
        |> Enum.filter(&String.starts_with?(&1, "label="))
        |> Enum.map(&(&1 |> String.replace_prefix("label=", "") |> URI.decode_www_form()))

      assert labels == ["Emergency Brake", "", "", "0", "", "", "Power"]
    end

    test "leaves out the name when there is none" do
      design = design!([gate(0, "A", 0.0, 0.0), gate(1, "B", 1.0, 1.0)])
      refute NotchDesign.generator_url(design) =~ "name="
    end
  end
end
