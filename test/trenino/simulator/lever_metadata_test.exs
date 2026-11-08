defmodule Trenino.Simulator.LeverMetadataTest do
  use Trenino.SerialSafetyCase, async: true

  alias Trenino.Simulator.Client
  alias Trenino.Simulator.ControlDetector
  alias Trenino.Simulator.LeverMetadata
  alias Trenino.Simulator.LeverMetadata.Label

  setup :verify_on_exit!

  defp label(name, min, max, opts \\ []) do
    %Label{
      name: name,
      min: min,
      max: max,
      source: Keyword.get(opts, :source, :output),
      template?: String.contains?(name, "{")
    }
  end

  describe "parse_labels/1" do
    test "reads names, sources and template flags, sorted by range start" do
      raw = %{
        "namedValues" => [
          %{
            "valueSource" => "Output",
            "valueRange" => %{"min" => 0.5, "max" => 4.5},
            "displayName" => "{PowerNumber}",
            "bDisplayNameIsFormatString" => false
          },
          %{
            "valueSource" => "Input",
            "valueRange" => %{"min" => -0.05, "max" => 0.05},
            "displayName" => "Off",
            "bDisplayNameIsFormatString" => false
          },
          %{"valueSource" => "Output", "displayName" => "broken"}
        ]
      }

      assert [
               %Label{name: "Off", source: :input, min: -0.05, max: 0.05, template?: false},
               %Label{name: "{PowerNumber}", source: :output, min: 0.5, max: 4.5, template?: true}
             ] = LeverMetadata.parse_labels(raw)
    end

    test "returns no labels when DisplayInfo has none" do
      assert LeverMetadata.parse_labels(nil) == []
      assert LeverMetadata.parse_labels(%{"mode" => "None"}) == []
    end
  end

  describe "display_name/2" do
    test "resolves placeholders" do
      assert LeverMetadata.display_name(label("{BrakePercent} Brake", -1.0, -0.25), nil) ==
               "Brake"

      assert LeverMetadata.display_name(label("B{BrakeText}", -3.5, -0.5), -3.0) == "B3"
      assert LeverMetadata.display_name(label("P{PowerPos}", 0.5, 4.5), 2.0) == "P2"
      assert LeverMetadata.display_name(label("{PowerNumber}", 0.5, 4.5), 2.0) == "Power 2"
      assert LeverMetadata.display_name(label("{Power}", 0.1, 1.0), nil) == "Power"
      assert LeverMetadata.display_name(label("Service {%}", 0.0, 1.0), nil) == "Service"
      assert LeverMetadata.display_name(label("Emergency", -2.5, -1.5), -2.0) == "Emergency"
    end
  end

  describe "label_for/3" do
    test "picks the narrowest label containing the value" do
      labels = [label("Off", -0.5, 6.5), label("Full", 1.5, 2.5)]

      assert %Label{name: "Full"} = LeverMetadata.label_for(labels, :output, 2.0)
      assert %Label{name: "Off"} = LeverMetadata.label_for(labels, :output, 0.0)
      assert LeverMetadata.label_for(labels, :input, 2.0) == nil
    end

    test "matches zero-width labels" do
      assert %Label{name: "N3"} = LeverMetadata.label_for([label("N3", 3.0, 3.0)], :output, 3.0)
    end
  end

  describe "read/2" do
    test "reads role, ranges and labels without moving the lever" do
      stub(Req, :request, fn _req, opts ->
        refute opts[:method] == :patch

        values =
          case opts[:url] |> URI.decode() |> String.split(".") |> List.last() do
            "GetNotchCount" -> %{"ReturnValue" => 4}
            "InputIdentifier" -> %{"identifier" => "Throttle"}
            "GetMinimumInputValue" -> %{"ReturnValue" => 0}
            "GetMaximumInputValue" -> %{"ReturnValue" => 1}
            "GetMinimumOutputValue" -> %{"ReturnValue" => -1}
            "GetMaximumOutputValue" -> %{"ReturnValue" => 1}
            "GetCurrentNotchIndex" -> %{"ReturnValue" => 0}
            "DisplayInfo" -> %{"namedValues" => []}
            _ -> %{"ReturnValue" => 0.0}
          end

        {:ok, %Req.Response{status: 200, body: %{"Result" => "Success", "Values" => values}}}
      end)

      client = Client.new("http://localhost:31270", "key")

      assert {:ok, %LeverMetadata{} = lever} =
               LeverMetadata.read(client, "CurrentDrivableActor/Throttle_F")

      assert lever.role == "Throttle"
      assert lever.node_name == "Throttle_F"
      assert lever.notch_count == 4
      assert {lever.input_min, lever.input_max} == {0.0, 1.0}
      assert {lever.output_min, lever.output_max} == {-1.0, 1.0}
    end
  end

  describe "ControlDetector.rank_levers/3" do
    defp lever(node_name, role),
      do: %LeverMetadata{node_name: node_name, role: role, control_path: "X/#{node_name}"}

    defp twin_cab do
      [
        lever("TrainBrake_F", "AutomaticBrake"),
        lever("TrainBrake_B", "AutomaticBrake"),
        lever("DirectBrake_F", "IndependentBrake"),
        lever("DynamicBrake_F", "DynamicBrake"),
        lever("Reverser_F", "Reverser"),
        lever("Throttle_F", "Throttle"),
        lever("Throttle_B", "Throttle"),
        lever("Wiper_F", "Wipers")
      ]
    end

    defp top(levers, name), do: levers |> ControlDetector.rank_levers(name) |> hd()

    test "matches by role, front cab first" do
      assert %{lever: %{node_name: "Throttle_F"}, score: 1.0} = top(twin_cab(), "Throttle")
      assert %{lever: %{node_name: "Throttle_F"}} = top(twin_cab(), "Power lever")
      assert %{lever: %{node_name: "TrainBrake_F"}} = top(twin_cab(), "Brake")
      assert %{lever: %{node_name: "DirectBrake_F"}} = top(twin_cab(), "Independent brake")
      assert %{lever: %{node_name: "DynamicBrake_F"}} = top(twin_cab(), "Dynamic brake")
      assert %{lever: %{node_name: "Reverser_F"}} = top(twin_cab(), "Direction")
    end

    test "falls back to the node name when the role does not match" do
      levers = [lever("PowerHandle(IrregularLever)", nil), lever("Horn(IrregularLever)", "Horn")]

      assert %{lever: %{node_name: "PowerHandle(IrregularLever)"}} = top(levers, "Power Handle")
    end

    test "does not offer the train brake for a brake the train does not have" do
      levers = [lever("Westcode3StepBrake", "AutomaticBrake"), lever("Throttle", "Throttle")]

      assert ControlDetector.rank_levers(levers, "Independent brake") == []
      assert ControlDetector.rank_levers(levers, "Dynamic brake") == []
      assert %{lever: %{node_name: "Westcode3StepBrake"}} = top(levers, "Train brake")
    end

    test "leaves out poor matches" do
      assert ControlDetector.rank_levers(twin_cab(), "Pantograph") == []
    end
  end
end
