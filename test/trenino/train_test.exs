defmodule Trenino.TrainTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.{Train, Element, LeverConfig, ButtonInputBinding, Notch}

  describe "create_train/1" do
    test "creates a train with valid attributes" do
      attrs = %{name: "Class 66", identifier: "BR_Class_66", description: "Freight locomotive"}

      assert {:ok, %Train{} = train} = TrainContext.create_train(attrs)
      assert train.name == "Class 66"
      assert train.identifier == "BR_Class_66"
      assert train.description == "Freight locomotive"
    end

    test "creates a train without description" do
      attrs = %{name: "Class 66", identifier: "BR_Class_66"}

      assert {:ok, %Train{} = train} = TrainContext.create_train(attrs)
      assert train.description == nil
    end

    test "returns error changeset with missing name" do
      attrs = %{identifier: "BR_Class_66"}

      assert {:error, changeset} = TrainContext.create_train(attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset with missing identifier" do
      attrs = %{name: "Class 66"}

      assert {:error, changeset} = TrainContext.create_train(attrs)
      assert %{identifier: ["can't be blank"]} = errors_on(changeset)
    end

    test "enforces unique identifier" do
      attrs = %{name: "Class 66", identifier: "BR_Class_66"}

      assert {:ok, _train} = TrainContext.create_train(attrs)
      assert {:error, changeset} = TrainContext.create_train(attrs)
      assert %{identifier: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_train/2" do
    test "returns train by id" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, %Train{} = found} = TrainContext.get_train(train.id)
      assert found.id == train.id
      assert found.name == "Class 66"
    end

    test "returns error when train not found" do
      assert {:error, :not_found} = TrainContext.get_train(999_999)
    end

    test "preloads associations when requested" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, _element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, found} = TrainContext.get_train(train.id, preload: [:elements])

      assert length(found.elements) == 1
    end
  end

  describe "get_train_by_identifier/1" do
    test "returns train with matching identifier" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, %Train{} = found} = TrainContext.get_train_by_identifier("BR_Class_66")
      assert found.id == train.id
    end

    test "returns error when no train matches identifier" do
      assert {:error, :not_found} = TrainContext.get_train_by_identifier("NonExistent")
    end

    test "preloads elements with lever_config" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, _config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      {:ok, found} = TrainContext.get_train_by_identifier("BR_Class_66")

      assert length(found.elements) == 1
      assert hd(found.elements).lever_config != nil
    end
  end

  describe "update_train/2" do
    test "updates train with valid attributes" do
      {:ok, train} = TrainContext.create_train(%{name: "Original", identifier: "BR_Class_66"})

      assert {:ok, %Train{} = updated} = TrainContext.update_train(train, %{name: "Updated"})
      assert updated.name == "Updated"
    end

    test "updates description" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, %Train{} = updated} =
               TrainContext.update_train(train, %{description: "New description"})

      assert updated.description == "New description"
    end
  end

  describe "delete_train/1" do
    test "deletes train" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, %Train{}} = TrainContext.delete_train(train)
      assert {:error, :not_found} = TrainContext.get_train(train.id)
    end

    test "cascade deletes associated elements" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, _element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:ok, _} = TrainContext.delete_train(train)
      assert {:ok, []} = TrainContext.list_elements(train.id)
    end
  end

  describe "list_trains/1" do
    test "returns empty list when no trains exist" do
      assert [] = TrainContext.list_trains()
    end

    test "returns trains ordered by name" do
      {:ok, _} = TrainContext.create_train(%{name: "Zebra", identifier: "id1"})
      {:ok, _} = TrainContext.create_train(%{name: "Alpha", identifier: "id2"})
      {:ok, _} = TrainContext.create_train(%{name: "Beta", identifier: "id3"})

      trains = TrainContext.list_trains()
      names = Enum.map(trains, & &1.name)

      assert names == ["Alpha", "Beta", "Zebra"]
    end

    test "preloads associations when requested" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, _element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      [found] = TrainContext.list_trains(preload: [:elements])

      assert length(found.elements) == 1
    end
  end

  describe "create_element/2" do
    test "creates element with valid attributes" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      attrs = %{name: "Throttle", type: :lever}

      assert {:ok, %Element{} = element} = TrainContext.create_element(train.id, attrs)
      assert element.train_id == train.id
      assert element.name == "Throttle"
      assert element.type == :lever
    end

    test "accepts string type" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      attrs = %{name: "Throttle", type: "lever"}

      assert {:ok, %Element{} = element} = TrainContext.create_element(train.id, attrs)
      assert element.type == :lever
    end

    test "returns error changeset with missing name" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:error, changeset} = TrainContext.create_element(train.id, %{type: :lever})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset with missing type" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:error, changeset} = TrainContext.create_element(train.id, %{name: "Throttle"})
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "list_elements/1" do
    test "returns empty list when no elements exist" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, []} = TrainContext.list_elements(train.id)
    end

    test "returns elements ordered by name" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      {:ok, _} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Brake", type: :lever})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Reverser", type: :lever})

      {:ok, elements} = TrainContext.list_elements(train.id)
      names = Enum.map(elements, & &1.name)

      assert names == ["Brake", "Reverser", "Throttle"]
    end

    test "preloads lever_config with notches" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, _config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      {:ok, [found]} = TrainContext.list_elements(train.id)

      assert found.lever_config != nil
      assert found.lever_config.notches == []
    end
  end

  describe "get_element/2" do
    test "returns element by id" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:ok, %Element{} = found} = TrainContext.get_element(element.id)
      assert found.id == element.id
    end

    test "returns error when element not found" do
      assert {:error, :not_found} = TrainContext.get_element(999_999)
    end
  end

  describe "delete_element/1" do
    test "deletes element" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:ok, %Element{}} = TrainContext.delete_element(element)
      assert {:error, :not_found} = TrainContext.get_element(element.id)
    end
  end

  describe "create_lever_config/2" do
    test "creates lever config with valid attributes" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      attrs = %{
        min_endpoint: "CurrentDrivableActor/Throttle.MinValue",
        max_endpoint: "CurrentDrivableActor/Throttle.MaxValue",
        value_endpoint: "CurrentDrivableActor/Throttle.InputValue"
      }

      assert {:ok, %LeverConfig{} = config} = TrainContext.create_lever_config(element.id, attrs)
      assert config.element_id == element.id
      assert config.min_endpoint == "CurrentDrivableActor/Throttle.MinValue"
      assert config.calibrated_at == nil
    end

    test "returns error changeset with missing required fields" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:error, changeset} = TrainContext.create_lever_config(element.id, %{})

      errors = errors_on(changeset)
      assert %{min_endpoint: ["can't be blank"]} = errors
      assert %{max_endpoint: ["can't be blank"]} = errors
      assert %{value_endpoint: ["can't be blank"]} = errors
    end
  end

  describe "get_lever_config/1" do
    test "returns lever config by element id" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      assert {:ok, %LeverConfig{} = found} = TrainContext.get_lever_config(element.id)
      assert found.id == config.id
    end

    test "returns error when no config exists" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:error, :not_found} = TrainContext.get_lever_config(element.id)
    end

    test "preloads notches" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      {:ok, _} =
        TrainContext.save_calibration(config, [
          %{type: :gate, value: 0.0},
          %{type: :gate, value: 1.0}
        ])

      {:ok, found} = TrainContext.get_lever_config(element.id)

      assert length(found.notches) == 2
    end
  end

  describe "save_calibration/2" do
    test "saves notches and sets calibrated_at" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      notches = [
        %{type: :gate, value: 0.0, description: "Off"},
        %{type: :linear, value: 0.5, min_value: 0.0, max_value: 1.0},
        %{type: :gate, value: 1.0, description: "Full"}
      ]

      assert {:ok, %LeverConfig{} = updated} = TrainContext.save_calibration(config, notches)
      assert updated.calibrated_at != nil
      assert length(updated.notches) == 3

      [first, second, third] = Enum.sort_by(updated.notches, & &1.index)
      assert first.type == :gate
      assert first.value == 0.0
      assert first.description == "Off"
      assert first.index == 0

      assert second.type == :linear
      assert second.value == 0.5
      assert second.min_value == 0.0
      assert second.max_value == 1.0
      assert second.index == 1

      assert third.type == :gate
      assert third.value == 1.0
      assert third.description == "Full"
      assert third.index == 2
    end

    test "replaces existing notches" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      # First calibration
      {:ok, _} =
        TrainContext.save_calibration(config, [
          %{type: :gate, value: 0.0},
          %{type: :gate, value: 1.0}
        ])

      # Second calibration should replace
      {:ok, updated} =
        TrainContext.save_calibration(config, [
          %{type: :gate, value: 0.0},
          %{type: :gate, value: 0.5},
          %{type: :gate, value: 1.0}
        ])

      assert length(updated.notches) == 3
    end
  end

  describe "update_notch_description/2" do
    test "updates notch description" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      {:ok, saved} =
        TrainContext.save_calibration(config, [
          %{type: :gate, value: 0.0}
        ])

      notch = hd(saved.notches)

      assert {:ok, %Notch{} = updated} =
               TrainContext.update_notch_description(notch, "Idle Position")

      assert updated.description == "Idle Position"
    end

    test "clears notch description with nil" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      {:ok, saved} =
        TrainContext.save_calibration(config, [
          %{type: :gate, value: 0.0, description: "Old"}
        ])

      notch = hd(saved.notches)

      assert {:ok, %Notch{} = updated} = TrainContext.update_notch_description(notch, nil)
      assert updated.description == nil
    end
  end

  # Button element and binding tests

  describe "create_element/2 for button type" do
    test "creates button element with valid attributes" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      attrs = %{name: "Horn", type: :button}

      assert {:ok, %Element{} = element} = TrainContext.create_element(train.id, attrs)
      assert element.train_id == train.id
      assert element.name == "Horn"
      assert element.type == :button
    end

    test "accepts string button type" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      attrs = %{name: "Horn", type: "button"}

      assert {:ok, %Element{} = element} = TrainContext.create_element(train.id, attrs)
      assert element.type == :button
    end
  end

  describe "list_elements/1 with button elements" do
    test "returns both lever and button elements" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      {:ok, _} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Bell", type: :button})

      {:ok, elements} = TrainContext.list_elements(train.id)

      assert length(elements) == 3
      types = Enum.map(elements, & &1.type) |> Enum.sort()
      assert types == [:button, :button, :lever]
    end

    test "preloads button_binding for button elements" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      {:ok, _binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      {:ok, [found]} = TrainContext.list_elements(train.id)

      assert found.button_binding != nil
      assert found.button_binding.endpoint == "CurrentDrivableActor/Horn.InputValue"
    end
  end

  describe "get_button_binding/1" do
    setup do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      %{element: element, input: input, device: device}
    end

    test "returns button binding by element id", %{element: element, input: input} do
      {:ok, binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      assert {:ok, %ButtonInputBinding{} = found} = TrainContext.get_button_binding(element.id)
      assert found.id == binding.id
      assert found.endpoint == "CurrentDrivableActor/Horn.InputValue"
    end

    test "returns error when no binding exists", %{element: element} do
      assert {:error, :not_found} = TrainContext.get_button_binding(element.id)
    end

    test "preloads input with device", %{element: element, input: input, device: device} do
      {:ok, _binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      {:ok, found} = TrainContext.get_button_binding(element.id)

      assert found.input.id == input.id
      assert found.input.device.id == device.id
    end
  end

  describe "create_button_binding/3" do
    setup do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      %{element: element, input: input}
    end

    test "creates button binding with valid attributes", %{element: element, input: input} do
      attrs = %{endpoint: "CurrentDrivableActor/Horn.InputValue"}

      assert {:ok, %ButtonInputBinding{} = binding} =
               TrainContext.create_button_binding(element.id, input.id, attrs)

      assert binding.element_id == element.id
      assert binding.input_id == input.id
      assert binding.endpoint == "CurrentDrivableActor/Horn.InputValue"
      assert binding.on_value == 1.0
      assert binding.off_value == 0.0
      assert binding.enabled == true
    end

    test "creates button binding with custom on/off values", %{element: element, input: input} do
      attrs = %{
        endpoint: "CurrentDrivableActor/Horn.InputValue",
        on_value: 100.0,
        off_value: -50.0
      }

      assert {:ok, %ButtonInputBinding{} = binding} =
               TrainContext.create_button_binding(element.id, input.id, attrs)

      assert binding.on_value == 100.0
      assert binding.off_value == -50.0
    end

    test "returns error when endpoint is missing", %{element: element, input: input} do
      assert {:error, changeset} = TrainContext.create_button_binding(element.id, input.id, %{})

      assert %{endpoint: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_button_binding/2" do
    setup do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      {:ok, binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      %{binding: binding}
    end

    test "updates endpoint", %{binding: binding} do
      {:ok, updated} =
        TrainContext.update_button_binding(binding, %{
          endpoint: "CurrentDrivableActor/Bell.InputValue"
        })

      assert updated.endpoint == "CurrentDrivableActor/Bell.InputValue"
    end

    test "updates on/off values", %{binding: binding} do
      {:ok, updated} =
        TrainContext.update_button_binding(binding, %{on_value: 5.0, off_value: -5.0})

      assert updated.on_value == 5.0
      assert updated.off_value == -5.0
    end

    test "updates enabled flag", %{binding: binding} do
      {:ok, updated} = TrainContext.update_button_binding(binding, %{enabled: false})

      assert updated.enabled == false
    end
  end

  describe "delete_button_binding/1" do
    setup do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      {:ok, _binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      %{element: element}
    end

    test "deletes button binding by element id", %{element: element} do
      assert :ok = TrainContext.delete_button_binding(element.id)
      assert {:error, :not_found} = TrainContext.get_button_binding(element.id)
    end

    test "returns error when no binding exists" do
      assert {:error, :not_found} = TrainContext.delete_button_binding(999_999)
    end
  end

  describe "set_button_binding_enabled/2" do
    setup do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      {:ok, _binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      %{element: element}
    end

    test "disables button binding", %{element: element} do
      {:ok, updated} = TrainContext.set_button_binding_enabled(element.id, false)

      assert updated.enabled == false
    end

    test "enables button binding", %{element: element} do
      # First disable it
      TrainContext.set_button_binding_enabled(element.id, false)

      # Then enable it
      {:ok, updated} = TrainContext.set_button_binding_enabled(element.id, true)

      assert updated.enabled == true
    end

    test "returns error when no binding exists" do
      assert {:error, :not_found} = TrainContext.set_button_binding_enabled(999_999, true)
    end
  end

  describe "list_button_bindings_for_train/1" do
    setup do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input1} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      {:ok, input2} =
        Hardware.create_input(device.id, %{pin: 6, input_type: :button, debounce: 20})

      %{train: train, input1: input1, input2: input2}
    end

    test "returns empty list when no button bindings exist", %{train: train} do
      assert [] = TrainContext.list_button_bindings_for_train(train.id)
    end

    test "returns button bindings for train", %{train: train, input1: input1, input2: input2} do
      {:ok, element1} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, element2} = TrainContext.create_element(train.id, %{name: "Bell", type: :button})

      {:ok, _} =
        TrainContext.create_button_binding(element1.id, input1.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      {:ok, _} =
        TrainContext.create_button_binding(element2.id, input2.id, %{
          endpoint: "CurrentDrivableActor/Bell.InputValue"
        })

      bindings = TrainContext.list_button_bindings_for_train(train.id)

      assert length(bindings) == 2
    end

    test "does not return bindings from other trains", %{train: train, input1: input1} do
      {:ok, other_train} =
        TrainContext.create_train(%{name: "Other Train", identifier: "other_train"})

      {:ok, element1} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

      {:ok, element2} =
        TrainContext.create_element(other_train.id, %{name: "Horn", type: :button})

      {:ok, _} =
        TrainContext.create_button_binding(element1.id, input1.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      {:ok, input3} =
        Hardware.create_input(
          (Hardware.list_all_inputs(include_uncalibrated: true) |> hd()).device_id,
          %{pin: 7, input_type: :button, debounce: 20}
        )

      {:ok, _} =
        TrainContext.create_button_binding(element2.id, input3.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      bindings = TrainContext.list_button_bindings_for_train(train.id)

      assert length(bindings) == 1
    end

    test "preloads element and input with device", %{train: train, input1: input1} do
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

      {:ok, _} =
        TrainContext.create_button_binding(element.id, input1.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      [binding] = TrainContext.list_button_bindings_for_train(train.id)

      assert binding.element.name == "Horn"
      assert binding.input.pin == 5
      assert binding.input.device.name == "Test Device"
    end
  end

  describe "list_button_elements/1" do
    test "returns only button elements" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      {:ok, _} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Bell", type: :button})

      elements = TrainContext.list_button_elements(train.id)

      assert length(elements) == 2
      assert Enum.all?(elements, &(&1.type == :button))
    end

    test "returns elements ordered by name" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      {:ok, _} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Bell", type: :button})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Wiper", type: :button})

      elements = TrainContext.list_button_elements(train.id)
      names = Enum.map(elements, & &1.name)

      assert names == ["Bell", "Horn", "Wiper"]
    end

    test "returns empty list when no button elements exist" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      {:ok, _} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert [] = TrainContext.list_button_elements(train.id)
    end
  end

  # ============================================================================
  # Sequence tests
  # ============================================================================

  describe "create_sequence/2" do
    test "creates a sequence with valid attributes" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Door Open"})
      assert sequence.name == "Door Open"
      assert sequence.train_id == train.id
    end

    test "requires name" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:error, changeset} = TrainContext.create_sequence(train.id, %{})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "enforces unique name per train" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, _} = TrainContext.create_sequence(train.id, %{name: "Door Open"})
      assert {:error, changeset} = TrainContext.create_sequence(train.id, %{name: "Door Open"})
      assert "has already been taken" in errors_on(changeset).train_id
    end
  end

  describe "get_sequence/1" do
    test "returns sequence with commands preloaded" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Door Open"})

      {:ok, _} =
        TrainContext.add_sequence_command(sequence, %{
          endpoint: "Horn.InputValue",
          value: 1.0
        })

      assert {:ok, fetched} = TrainContext.get_sequence(sequence.id)
      assert fetched.name == "Door Open"
      assert length(fetched.commands) == 1
    end

    test "returns error for non-existent sequence" do
      assert {:error, :not_found} = TrainContext.get_sequence(999_999)
    end
  end

  describe "list_sequences/1" do
    test "returns all sequences for a train" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      {:ok, _} = TrainContext.create_sequence(train.id, %{name: "Door Open"})
      {:ok, _} = TrainContext.create_sequence(train.id, %{name: "Door Close"})

      sequences = TrainContext.list_sequences(train.id)
      assert length(sequences) == 2
    end

    test "returns sequences ordered by name" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      {:ok, _} = TrainContext.create_sequence(train.id, %{name: "Zebra"})
      {:ok, _} = TrainContext.create_sequence(train.id, %{name: "Alpha"})

      sequences = TrainContext.list_sequences(train.id)
      names = Enum.map(sequences, & &1.name)
      assert names == ["Alpha", "Zebra"]
    end

    test "does not return sequences from other trains" do
      {:ok, train1} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, train2} = TrainContext.create_train(%{name: "Class 43", identifier: "BR_Class_43"})

      {:ok, _} = TrainContext.create_sequence(train1.id, %{name: "Horn"})
      {:ok, _} = TrainContext.create_sequence(train2.id, %{name: "Bell"})

      sequences = TrainContext.list_sequences(train1.id)
      assert length(sequences) == 1
      assert hd(sequences).name == "Horn"
    end
  end

  describe "set_sequence_commands/2" do
    test "sets commands with auto-assigned positions" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Door Open"})

      commands = [
        %{endpoint: "Key.InputValue", value: 1.0, delay_ms: 500},
        %{endpoint: "Rotary.InputValue", value: 0.5, delay_ms: 250},
        %{endpoint: "Open.InputValue", value: 1.0}
      ]

      assert {:ok, created} = TrainContext.set_sequence_commands(sequence, commands)
      assert length(created) == 3

      positions = Enum.map(created, & &1.position)
      assert positions == [0, 1, 2]
    end

    test "replaces existing commands" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Door Open"})

      {:ok, _} =
        TrainContext.set_sequence_commands(sequence, [
          %{endpoint: "Old.InputValue", value: 1.0}
        ])

      {:ok, _} =
        TrainContext.set_sequence_commands(sequence, [
          %{endpoint: "New.InputValue", value: 2.0}
        ])

      {:ok, fetched} = TrainContext.get_sequence(sequence.id)
      assert length(fetched.commands) == 1
      assert hd(fetched.commands).endpoint == "New.InputValue"
    end

    test "rounds float values to 2 decimal places" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Test"})

      {:ok, [cmd]} =
        TrainContext.set_sequence_commands(sequence, [
          %{endpoint: "Test.InputValue", value: 0.123456}
        ])

      assert cmd.value == 0.12
    end
  end

  describe "add_sequence_command/2" do
    test "adds command at the end" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Test"})

      {:ok, cmd1} =
        TrainContext.add_sequence_command(sequence, %{endpoint: "First.InputValue", value: 1.0})

      {:ok, cmd2} =
        TrainContext.add_sequence_command(sequence, %{endpoint: "Second.InputValue", value: 2.0})

      assert cmd1.position == 0
      assert cmd2.position == 1
    end
  end

  describe "delete_sequence/1" do
    test "deletes sequence and its commands" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Test"})

      {:ok, _} =
        TrainContext.set_sequence_commands(sequence, [
          %{endpoint: "Test.InputValue", value: 1.0}
        ])

      assert {:ok, _} = TrainContext.delete_sequence(sequence)
      assert {:error, :not_found} = TrainContext.get_sequence(sequence.id)
    end
  end
end
