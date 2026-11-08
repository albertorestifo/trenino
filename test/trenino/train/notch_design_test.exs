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
    test "BR430: Emergency and the zero gate are Deep, ranges are Smooth, Power gets an end stop" do
      design = design!(notches(:br430_master_controller))

      assert design.positions == [
               {:deep, "Emergency Brake"},
               {:smooth, ""},
               {:deep, "0"},
               {:smooth, ""},
               {:standard, "Power"}
             ]
    end

    test "M9: Emergency and Coast are Deep, the longer power range gets two Smooth positions" do
      design = design!(notches(:m9_master_controller))

      assert design.positions == [
               {:deep, "Emergency"},
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

      assert design.positions == [
               {:standard, "Release"},
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
               {:standard, ""},
               {:smooth, ""},
               {:smooth, ""},
               {:standard, "Power"}
             ]
    end

    test "a range without simulator inputs gets one Smooth position" do
      design =
        design!([
          %Notch{index: 0, type: :gate, value: 0.0, description: "Off"},
          %Notch{index: 1, type: :linear, min_value: 0.0, max_value: 1.0, description: "Power"}
        ])

      assert design.positions == [{:deep, "Off"}, {:smooth, ""}, {:standard, "Power"}]
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
               "positions" => "5",
               "deep" => "1,3",
               "smooth" => "2,4",
               "label" => "Power",
               "name" => "BR430 Master controller"
             }

      labels =
        query
        |> String.split("&")
        |> Enum.filter(&String.starts_with?(&1, "label="))
        |> Enum.map(&(&1 |> String.replace_prefix("label=", "") |> URI.decode_www_form()))

      assert labels == ["Emergency Brake", "", "0", "", "Power"]
    end

    test "leaves out the name when there is none" do
      design = design!([gate(0, "A", 0.0, 0.0), gate(1, "B", 1.0, 1.0)])
      refute NotchDesign.generator_url(design) =~ "name="
    end
  end
end
