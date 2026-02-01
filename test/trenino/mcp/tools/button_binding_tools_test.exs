defmodule Trenino.MCP.Tools.ButtonBindingToolsTest do
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.MCP.Tools.ButtonBindingTools
  alias Trenino.Train, as: TrainContext

  setup do
    {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
    {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
    {:ok, device} = Hardware.create_device(%{name: "Arduino Uno"})

    {:ok, input} =
      Hardware.create_input(device.id, %{
        pin: 5,
        input_type: :button,
        name: "Button 5",
        debounce: 20
      })

    %{train: train, element: element, input: input}
  end

  describe "get_button_binding" do
    test "returns error when no binding exists", %{element: element} do
      assert {:error, message} =
               ButtonBindingTools.execute("get_button_binding", %{"element_id" => element.id})

      assert message =~ "No button binding found"
    end

    test "returns existing binding", %{element: element, input: input} do
      {:ok, _} =
        TrainContext.create_button_binding(element.id, input.id, %{
          mode: :simple,
          endpoint: "Horn.InputValue"
        })

      assert {:ok, %{button_binding: binding}} =
               ButtonBindingTools.execute("get_button_binding", %{"element_id" => element.id})

      assert binding.mode == :simple
      assert binding.endpoint == "Horn.InputValue"
    end
  end

  describe "create_button_binding" do
    test "creates simple mode binding", %{element: element, input: input} do
      args = %{
        "element_id" => element.id,
        "input_id" => input.id,
        "mode" => "simple",
        "endpoint" => "Horn.InputValue",
        "on_value" => 1.0,
        "off_value" => 0.0
      }

      assert {:ok, %{button_binding: binding}} =
               ButtonBindingTools.execute("create_button_binding", args)

      assert binding.mode == :simple
      assert binding.endpoint == "Horn.InputValue"
      assert binding.on_value == 1.0
      assert binding.off_value == 0.0
    end

    test "creates momentary mode binding", %{element: element, input: input} do
      args = %{
        "element_id" => element.id,
        "input_id" => input.id,
        "mode" => "momentary",
        "endpoint" => "Horn.InputValue",
        "repeat_interval_ms" => 200
      }

      assert {:ok, %{button_binding: binding}} =
               ButtonBindingTools.execute("create_button_binding", args)

      assert binding.mode == :momentary
      assert binding.repeat_interval_ms == 200
    end

    test "creates keystroke mode binding", %{element: element, input: input} do
      args = %{
        "element_id" => element.id,
        "input_id" => input.id,
        "mode" => "keystroke",
        "keystroke" => "W"
      }

      assert {:ok, %{button_binding: binding}} =
               ButtonBindingTools.execute("create_button_binding", args)

      assert binding.mode == :keystroke
      assert binding.keystroke == "W"
    end

    test "creates sequence mode binding", %{train: train, element: element, input: input} do
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Test Sequence"})

      args = %{
        "element_id" => element.id,
        "input_id" => input.id,
        "mode" => "sequence",
        "on_sequence_id" => sequence.id
      }

      assert {:ok, %{button_binding: binding}} =
               ButtonBindingTools.execute("create_button_binding", args)

      assert binding.mode == :sequence
      assert binding.on_sequence_id == sequence.id
    end

    test "supports latching hardware type", %{element: element, input: input} do
      args = %{
        "element_id" => element.id,
        "input_id" => input.id,
        "mode" => "simple",
        "endpoint" => "Light.InputValue",
        "hardware_type" => "latching"
      }

      assert {:ok, %{button_binding: binding}} =
               ButtonBindingTools.execute("create_button_binding", args)

      assert binding.hardware_type == :latching
    end
  end

  describe "update_button_binding" do
    test "updates binding fields", %{element: element, input: input} do
      {:ok, _} =
        TrainContext.create_button_binding(element.id, input.id, %{
          mode: :simple,
          endpoint: "Horn.InputValue"
        })

      assert {:ok, %{button_binding: updated}} =
               ButtonBindingTools.execute("update_button_binding", %{
                 "element_id" => element.id,
                 "endpoint" => "Bell.InputValue",
                 "on_value" => 0.5
               })

      assert updated.endpoint == "Bell.InputValue"
      assert updated.on_value == 0.5
    end

    test "returns error for missing binding", %{train: train} do
      {:ok, other_element} =
        TrainContext.create_element(train.id, %{name: "Other", type: :button})

      assert {:error, message} =
               ButtonBindingTools.execute("update_button_binding", %{
                 "element_id" => other_element.id,
                 "endpoint" => "X"
               })

      assert message =~ "No button binding found"
    end
  end

  describe "delete_button_binding" do
    test "deletes an existing binding", %{element: element, input: input} do
      {:ok, _} =
        TrainContext.create_button_binding(element.id, input.id, %{
          mode: :simple,
          endpoint: "Horn.InputValue"
        })

      assert {:ok, %{deleted: true, element_id: eid}} =
               ButtonBindingTools.execute("delete_button_binding", %{
                 "element_id" => element.id
               })

      assert eid == element.id
    end

    test "returns error for missing binding", %{train: train} do
      {:ok, other_element} =
        TrainContext.create_element(train.id, %{name: "Other", type: :button})

      assert {:error, message} =
               ButtonBindingTools.execute("delete_button_binding", %{
                 "element_id" => other_element.id
               })

      assert message =~ "No button binding found"
    end
  end
end
