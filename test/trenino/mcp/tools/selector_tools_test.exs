defmodule Trenino.MCP.Tools.SelectorToolsTest do
  use Trenino.DataCase, async: true

  import Trenino.VirtualJoystickFixtures

  alias Trenino.MCP.ToolRegistry
  alias Trenino.MCP.Tools.SelectorTools
  alias Trenino.Train, as: TrainContext
  alias Trenino.VirtualJoystick

  @endpoint "CurrentDrivableActor/Headlights.InputValue"

  setup do
    {:ok, train} =
      TrainContext.create_train(%{name: "Test Train", identifiers: [%{identifier: "sel_tools"}]})

    {:ok, element} = TrainContext.create_element(train.id, %{name: "Lights", type: :selector})

    %{train: train, element: element, input: analog_input_fixture()}
  end

  defp set_value(value), do: %{"kind" => "set_value", "endpoint" => @endpoint, "value" => value}

  defp configure(element, args) do
    SelectorTools.execute("configure_selector", Map.put(args, "element_id", element.id))
  end

  test "registers its tools" do
    names = Enum.map(ToolRegistry.list_tools(), & &1.name)

    for name <- ~w(get_selector configure_selector set_selector_even_split delete_selector) do
      assert name in names
    end
  end

  describe "configure_selector" do
    test "creates a selector with evenly split positions", %{element: element, input: input} do
      args = %{
        "input_id" => input.id,
        "positions" => [
          %{"label" => "Off", "enter" => set_value(0.0)},
          %{"label" => "Dim", "enter" => set_value(0.5)},
          %{
            "label" => "Full",
            "enter" => set_value(1.0),
            "exit" => %{"kind" => "keystroke", "keystroke" => "L"}
          }
        ]
      }

      assert {:ok, %{selector: selector}} = configure(element, args)

      assert selector.input_id == input.id
      assert selector.enabled

      assert [
               %{index: 0, label: "Off", input_min: 0.0, input_max: 0.3},
               %{index: 1, label: "Dim", input_min: 0.37, input_max: 0.63},
               %{index: 2, label: "Full", input_min: 0.7, input_max: 1.0} = full
             ] = selector.positions

      assert full.enter == %{
               kind: :set_value,
               endpoint: @endpoint,
               value: 1.0,
               sequence_id: nil,
               keystroke: nil
             }

      assert full.exit.kind == :keystroke
      assert full.exit.keystroke == "L"
      assert hd(selector.positions).exit.kind == :none
    end

    test "uses explicit ranges and orders positions physically", %{element: element, input: input} do
      args = %{
        "input_id" => input.id,
        "positions" => [
          %{"label" => "High", "input_min" => 0.6, "input_max" => 1.0},
          %{"label" => "Low", "input_min" => 0.0, "input_max" => 0.4}
        ]
      }

      assert {:ok, %{selector: %{positions: [low, high]}}} = configure(element, args)
      assert %{index: 0, label: "Low", input_max: 0.4} = low
      assert %{index: 1, label: "High", input_min: 0.6} = high
    end

    test "rejects ranges on only some positions", %{element: element, input: input} do
      args = %{
        "input_id" => input.id,
        "positions" => [%{"input_min" => 0.0, "input_max" => 0.4}, %{}]
      }

      assert {:error, "give input_min and input_max for every position, or for none"} =
               configure(element, args)
    end

    test "rejects too few positions", %{element: element, input: input} do
      assert {:error, message} =
               configure(element, %{"input_id" => input.id, "positions" => [%{}]})

      assert message =~ "between 2 and 12"
    end

    test "rejects an unknown action kind", %{element: element, input: input} do
      args = %{
        "input_id" => input.id,
        "positions" => [%{"enter" => %{"kind" => "explode"}}, %{}]
      }

      assert {:error, message} = configure(element, args)
      assert message =~ "enter.kind must be one of"
    end

    test "reports nested validation errors per position", %{element: element, input: input} do
      args = %{
        "input_id" => input.id,
        "positions" => [%{}, %{"enter" => %{"kind" => "set_value"}}]
      }

      assert {:error, message} = configure(element, args)
      assert message =~ "positions[1].enter_endpoint can't be blank"
      assert message =~ "positions[1].enter_value can't be blank"
    end

    test "reports binding-level errors", %{element: element} do
      button = button_input_fixture()

      assert {:error, message} =
               configure(element, %{"input_id" => button.id, "positions" => [%{}, %{}]})

      assert message =~ "input_id must be an analog input"
    end

    test "updates only the given fields", %{element: element, input: input} do
      {:ok, _} =
        configure(element, %{"input_id" => input.id, "positions" => [%{"label" => "A"}, %{}]})

      assert {:ok, %{selector: selector}} = configure(element, %{"enabled" => false})
      refute selector.enabled
      assert [%{label: "A"}, _] = selector.positions
    end

    test "requires an input when creating", %{element: element} do
      assert {:error, message} = configure(element, %{"positions" => [%{}, %{}]})
      assert message =~ "input_id can't be blank"
    end

    test "explains a virtual joystick conflict and can replace it",
         %{element: element, input: input} do
      {:ok, _} = VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :slider_1})
      args = %{"input_id" => input.id, "positions" => [%{}, %{}]}

      assert {:error, message} = configure(element, args)
      assert message =~ "replace_joystick_mapping"

      assert {:ok, _} = configure(element, Map.put(args, "replace_joystick_mapping", true))
      assert VirtualJoystick.list_mappings() == []
    end
  end

  describe "set_selector_even_split" do
    setup %{element: element, input: input} do
      {:ok, _} =
        configure(element, %{
          "input_id" => input.id,
          "positions" => [
            %{
              "label" => "Off",
              "input_min" => 0.0,
              "input_max" => 0.1,
              "enter" => set_value(0.0)
            },
            %{"label" => "On", "input_min" => 0.9, "input_max" => 1.0, "enter" => set_value(1.0)}
          ]
        })

      :ok
    end

    test "re-splits keeping labels and actions", %{element: element} do
      assert {:ok, %{selector: %{positions: [off, on]}}} =
               SelectorTools.execute("set_selector_even_split", %{"element_id" => element.id})

      assert %{label: "Off", input_min: 0.0, input_max: 0.45, enter: %{value: +0.0}} = off
      assert %{label: "On", input_min: 0.55, input_max: 1.0, enter: %{value: 1.0}} = on
    end

    test "grows and shrinks the position count", %{element: element} do
      assert {:ok, %{selector: %{positions: positions}}} =
               SelectorTools.execute("set_selector_even_split", %{
                 "element_id" => element.id,
                 "count" => 4
               })

      assert [%{label: "Off"}, %{label: "On"}, %{label: nil, enter: %{kind: :none}}, _] =
               positions

      assert {:ok, %{selector: %{positions: [%{label: "Off"}, %{label: "On"}]}}} =
               SelectorTools.execute("set_selector_even_split", %{
                 "element_id" => element.id,
                 "count" => 2
               })
    end

    test "accepts a custom dead zone", %{element: element} do
      assert {:ok, %{selector: %{positions: [a, _]}}} =
               SelectorTools.execute("set_selector_even_split", %{
                 "element_id" => element.id,
                 "dead_zone" => 0.5
               })

      assert a.input_max == 0.37
    end

    test "validates count and dead zone", %{element: element} do
      assert {:error, "count must be between 2 and 12"} =
               SelectorTools.execute("set_selector_even_split", %{
                 "element_id" => element.id,
                 "count" => 13
               })

      assert {:error, "dead_zone must be between 0.05 and 0.5"} =
               SelectorTools.execute("set_selector_even_split", %{
                 "element_id" => element.id,
                 "dead_zone" => 0.9
               })
    end

    test "returns an error without a binding", %{train: train} do
      {:ok, other} = TrainContext.create_element(train.id, %{name: "Wipers", type: :selector})

      assert {:error, message} =
               SelectorTools.execute("set_selector_even_split", %{"element_id" => other.id})

      assert message =~ "No selector binding"
    end
  end

  describe "get_selector and delete_selector" do
    test "returns and deletes a selector", %{element: element, input: input} do
      {:ok, _} = configure(element, %{"input_id" => input.id, "positions" => [%{}, %{}]})

      assert {:ok, %{selector: %{element_id: element_id}}} =
               SelectorTools.execute("get_selector", %{"element_id" => element.id})

      assert element_id == element.id

      assert {:ok, %{deleted: true}} =
               SelectorTools.execute("delete_selector", %{"element_id" => element.id})

      assert {:error, _} = SelectorTools.execute("get_selector", %{"element_id" => element.id})
      assert {:error, _} = SelectorTools.execute("delete_selector", %{"element_id" => element.id})
    end
  end
end
