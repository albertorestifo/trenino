defmodule Trenino.MCP.Tools.TrainToolsTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware
  alias Trenino.MCP.Tools.TrainTools
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.SelectorMapper

  describe "list_trains" do
    test "returns empty list when no trains" do
      assert {:ok, %{trains: []}} = TrainTools.execute("list_trains", %{})
    end

    test "returns all trains" do
      {:ok, _} =
        TrainContext.create_train(%{
          name: "BR 146.2",
          identifiers: [%{identifier: "br146"}]
        })

      {:ok, _} =
        TrainContext.create_train(%{
          name: "Class 66",
          identifiers: [%{identifier: "class66"}]
        })

      assert {:ok, %{trains: trains}} = TrainTools.execute("list_trains", %{})
      assert length(trains) == 2

      names = Enum.map(trains, & &1.name)
      assert "BR 146.2" in names
      assert "Class 66" in names
    end

    test "returns train fields" do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "BR 146.2",
          identifiers: [
            %{identifier: "RVM_OTHER_DB_BR423"},
            %{identifier: "RVM_FSN_DB_BR423"}
          ],
          description: "Electric loco"
        })

      {:ok, %{trains: [result]}} = TrainTools.execute("list_trains", %{})

      assert result.id == train.id
      assert result.name == "BR 146.2"
      assert result.identifiers == ["RVM_FSN_DB_BR423", "RVM_OTHER_DB_BR423"]
      refute Map.has_key?(result, :identifier)
      assert result.description == "Electric loco"
    end
  end

  describe "get_train" do
    test "returns train with elements and bindings" do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "BR 146.2",
          identifiers: [
            %{identifier: "RVM_OTHER_DB_BR423"},
            %{identifier: "RVM_FSN_DB_BR423"}
          ]
        })

      {:ok, _element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, _element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:ok, %{train: result}} = TrainTools.execute("get_train", %{"train_id" => train.id})

      assert result.name == "BR 146.2"
      assert result.identifiers == ["RVM_FSN_DB_BR423", "RVM_OTHER_DB_BR423"]
      refute Map.has_key?(result, :identifier)
      assert length(result.elements) == 2

      element_names = Enum.map(result.elements, & &1.name)
      assert "Horn" in element_names
      assert "Throttle" in element_names
    end

    test "returns error for missing train" do
      assert {:error, message} = TrainTools.execute("get_train", %{"train_id" => -1})
      assert message =~ "not found"
    end

    test "includes output bindings, button bindings, and sequences" do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Test",
          identifiers: [%{identifier: "test"}]
        })

      {:ok, %{train: result}} = TrainTools.execute("get_train", %{"train_id" => train.id})

      assert result.output_bindings == []
      assert result.button_bindings == []
      assert result.selectors == []
      assert result.sequences == []
    end

    test "includes selectors with their positions" do
      {:ok, train} =
        TrainContext.create_train(%{name: "Test", identifiers: [%{identifier: "sel"}]})

      {:ok, element} = TrainContext.create_element(train.id, %{name: "Lights", type: :selector})
      {:ok, device} = Hardware.create_device(%{name: "Board"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 0, input_type: :analog, sensitivity: 5})

      {:ok, _} =
        Hardware.save_calibration(input.id, %{
          min_value: 0,
          max_value: 1023,
          max_hardware_value: 1023
        })

      positions =
        2
        |> SelectorMapper.even_split()
        |> Enum.map(&Map.merge(&1, %{enter_kind: :keystroke, enter_keystroke: "L"}))

      {:ok, _} =
        TrainContext.save_selector(element.id, %{input_id: input.id, positions: positions})

      {:ok, %{train: result}} = TrainTools.execute("get_train", %{"train_id" => train.id})

      assert [%{element_id: element_id, positions: [first, _]}] = result.selectors
      assert element_id == element.id

      assert first.enter == %{
               kind: :keystroke,
               keystroke: "L",
               endpoint: nil,
               value: nil,
               sequence_id: nil
             }
    end
  end
end
