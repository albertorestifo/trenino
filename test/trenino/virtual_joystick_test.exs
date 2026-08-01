defmodule Trenino.VirtualJoystickTest do
  use Trenino.DataCase, async: true

  alias Trenino.VirtualJoystick
  alias Trenino.VirtualJoystick.{Configuration, Mapping}
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.LeverInputBinding

  describe "get_configuration/0" do
    test "creates the singleton configuration with its defaults" do
      assert %Configuration{enabled: false, device_index: 1} =
               configuration =
               VirtualJoystick.get_configuration()

      assert configuration.id == 1
      assert VirtualJoystick.get_configuration().id == configuration.id
    end
  end

  describe "configuration validation" do
    test "accepts only device index 1" do
      changeset = Configuration.changeset(%Configuration{id: 1}, %{device_index: 2})

      assert "must be 1" in errors_on(changeset).device_index
    end
  end

  describe "put_mapping/2 and put_mapping/3" do
    test "maps a calibrated analog input to an axis and preloads its input associations" do
      analog = analog_input_fixture()

      assert {:ok, %Mapping{} = mapping} =
               VirtualJoystick.put_mapping(analog.id, %{target_type: :axis, axis: :slider_1})

      assert mapping.device_index == 1
      assert mapping.target_type == :axis
      assert mapping.axis == :slider_1
      assert mapping.button == nil
      assert mapping.inverted == false

      assert {:ok, fetched} = VirtualJoystick.get_mapping(mapping.id)
      assert fetched.input.id == analog.id
      assert fetched.input.device.id == analog.device_id
      assert fetched.input.calibration.input_id == analog.id
    end

    test "maps a button input to a button target" do
      button = button_input_fixture()

      assert {:ok, mapping} =
               VirtualJoystick.put_mapping(button.id, %{target_type: :button, button: 32})

      assert mapping.target_type == :button
      assert mapping.button == 32
      assert mapping.axis == nil
    end

    test "rejects an analog input mapped to a button" do
      analog = analog_input_fixture()

      assert {:error, changeset} =
               VirtualJoystick.put_mapping(analog.id, %{target_type: :button, button: 1})

      assert "must target an axis" in errors_on(changeset).target_type
    end

    test "rejects a button input mapped to an axis" do
      button = button_input_fixture()

      assert {:error, changeset} =
               VirtualJoystick.put_mapping(button.id, %{target_type: :axis, axis: :x})

      assert "must target a button" in errors_on(changeset).target_type
    end

    test "rejects values outside the eight allowed axes" do
      analog = analog_input_fixture()

      assert {:error, changeset} =
               VirtualJoystick.put_mapping(analog.id, %{target_type: :axis, axis: :pov})

      assert "is invalid" in errors_on(changeset).axis
    end

    test "rejects device indexes other than 1" do
      analog = analog_input_fixture()

      assert {:error, changeset} =
               VirtualJoystick.put_mapping(analog.id, %{
                 device_index: 2,
                 target_type: :axis,
                 axis: :x
               })

      assert "must be 1" in errors_on(changeset).device_index
    end

    test "rejects button targets outside 1 through 32" do
      button = button_input_fixture()

      assert {:error, changeset} =
               VirtualJoystick.put_mapping(button.id, %{target_type: :button, button: 33})

      assert "must be less than or equal to 32" in errors_on(changeset).button
    end

    test "updates an existing input mapping rather than creating a second mapping" do
      analog = analog_input_fixture()

      assert {:ok, first_mapping} =
               VirtualJoystick.put_mapping(analog.id, %{target_type: :axis, axis: :x})

      assert {:ok, updated_mapping} =
               VirtualJoystick.put_mapping(analog.id, %{target_type: :axis, axis: :y},
                 replace?: true
               )

      assert updated_mapping.id == first_mapping.id
      assert updated_mapping.axis == :y
      assert [only_mapping] = VirtualJoystick.list_mappings()
      assert only_mapping.id == first_mapping.id
    end

    test "uses the input id argument instead of a caller-supplied input_id attribute" do
      analog = analog_input_fixture()
      button = button_input_fixture()

      assert {:ok, mapping} =
               VirtualJoystick.put_mapping(analog.id, %{
                 input_id: button.id,
                 target_type: :axis,
                 axis: :x
               })

      assert mapping.input_id == analog.id
      assert [only_mapping] = VirtualJoystick.list_mappings()
      assert only_mapping.input_id == analog.id
    end
  end

  describe "mapping database constraints" do
    test "enforces one mapping per input" do
      analog = analog_input_fixture()

      assert {:ok, _mapping} =
               Repo.insert(
                 Mapping.changeset(%Mapping{}, %{
                   input_id: analog.id,
                   target_type: :axis,
                   axis: :x
                 })
               )

      assert {:error, changeset} =
               Repo.insert(
                 Mapping.changeset(%Mapping{}, %{
                   input_id: analog.id,
                   target_type: :axis,
                   axis: :y
                 })
               )

      assert "has already been taken" in errors_on(changeset).input_id
    end

    test "enforces a unique axis target for device 1" do
      first = analog_input_fixture()
      second = analog_input_fixture(%{pin: 3})

      assert {:ok, _mapping} =
               VirtualJoystick.put_mapping(first.id, %{target_type: :axis, axis: :rx})

      assert {:error, changeset} =
               VirtualJoystick.put_mapping(second.id, %{target_type: :axis, axis: :rx})

      assert "has already been taken" in errors_on(changeset).axis
    end

    test "enforces a unique button target for device 1" do
      first = button_input_fixture()
      second = button_input_fixture(%{pin: 4})

      assert {:ok, _mapping} =
               VirtualJoystick.put_mapping(first.id, %{target_type: :button, button: 1})

      assert {:error, changeset} =
               VirtualJoystick.put_mapping(second.id, %{target_type: :button, button: 1})

      assert "has already been taken" in errors_on(changeset).button
    end
  end

  describe "list_mappings/0, get_mapping/1, and delete_mapping/1" do
    test "lists mappings with their inputs preloaded and deletes a mapping" do
      analog = analog_input_fixture()

      assert {:ok, mapping} =
               VirtualJoystick.put_mapping(analog.id, %{target_type: :axis, axis: :z})

      assert [listed] = VirtualJoystick.list_mappings()
      assert listed.input.id == analog.id
      assert listed.input.device.id == analog.device_id
      assert listed.input.calibration.input_id == analog.id

      assert {:ok, deleted} = VirtualJoystick.delete_mapping(mapping.id)
      assert deleted.id == mapping.id
      assert {:error, :not_found} = VirtualJoystick.get_mapping(mapping.id)
    end
  end

  describe "exclusive input destinations" do
    test "rejects a virtual axis mapping for an API-bound input unless replacement removes every enabled lever binding" do
      input = analog_input_fixture()
      unrelated_input = analog_input_fixture(%{pin: 3})
      first_config = lever_config_fixture("First", "first")
      second_config = lever_config_fixture("Second", "second")
      unrelated_config = lever_config_fixture("Unrelated", "unrelated")

      assert {:ok, _} = TrainContext.bind_input(first_config.id, input.id)
      assert {:ok, _} = TrainContext.bind_input(second_config.id, input.id)

      assert {:ok, unrelated_binding} =
               TrainContext.bind_input(unrelated_config.id, unrelated_input.id)

      assert {:error, :destination_conflict} =
               VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :x})

      assert {:ok, _mapping} =
               VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :x},
                 replace?: true
               )

      assert {:error, :not_found} = TrainContext.get_binding(first_config.id)
      assert {:error, :not_found} = TrainContext.get_binding(second_config.id)
      assert {:ok, retained} = TrainContext.get_binding(unrelated_config.id)
      assert retained.id == unrelated_binding.id
    end

    test "rejects a virtual button mapping for an API-bound input unless replacement removes enabled button bindings" do
      input = button_input_fixture()
      unrelated_input = button_input_fixture(%{pin: 4})
      element = button_element_fixture("Horn", "horn")
      unrelated_element = button_element_fixture("Bell", "bell")

      assert {:ok, _} =
               TrainContext.create_button_binding(element.id, input.id, %{
                 endpoint: "Horn.InputValue"
               })

      assert {:ok, unrelated_binding} =
               TrainContext.create_button_binding(unrelated_element.id, unrelated_input.id, %{
                 endpoint: "Bell.InputValue"
               })

      assert {:error, :destination_conflict} =
               VirtualJoystick.put_mapping(input.id, %{target_type: :button, button: 1})

      assert {:ok, _mapping} =
               VirtualJoystick.put_mapping(input.id, %{target_type: :button, button: 1},
                 replace?: true
               )

      assert {:error, :not_found} = TrainContext.get_button_binding(element.id)
      assert {:ok, retained} = TrainContext.get_button_binding(unrelated_element.id)
      assert retained.id == unrelated_binding.id
    end

    test "binding a lever input mapped to vJoy requires replacement and preserves unrelated mappings" do
      mapped_input = analog_input_fixture()
      unrelated_input = analog_input_fixture(%{pin: 3})
      config = lever_config_fixture("Throttle", "throttle")

      assert {:ok, mapping} =
               VirtualJoystick.put_mapping(mapped_input.id, %{target_type: :axis, axis: :x})

      assert {:ok, unrelated_mapping} =
               VirtualJoystick.put_mapping(unrelated_input.id, %{target_type: :axis, axis: :y})

      assert {:error, :destination_conflict} = TrainContext.bind_input(config.id, mapped_input.id)

      assert {:ok, _binding} = TrainContext.bind_input(config.id, mapped_input.id, replace?: true)
      assert {:error, :not_found} = VirtualJoystick.get_mapping(mapping.id)
      assert {:ok, retained} = VirtualJoystick.get_mapping(unrelated_mapping.id)
      assert retained.id == unrelated_mapping.id
    end

    test "creating a button binding for a vJoy-mapped input requires replacement" do
      mapped_input = button_input_fixture()
      unrelated_input = button_input_fixture(%{pin: 4})
      element = button_element_fixture("Horn", "horn")

      assert {:ok, mapping} =
               VirtualJoystick.put_mapping(mapped_input.id, %{target_type: :button, button: 1})

      assert {:ok, _unrelated_mapping} =
               VirtualJoystick.put_mapping(unrelated_input.id, %{target_type: :button, button: 2})

      assert {:error, :destination_conflict} =
               TrainContext.create_button_binding(element.id, mapped_input.id, %{
                 endpoint: "Horn.InputValue"
               })

      assert {:ok, _binding} =
               TrainContext.create_button_binding(
                 element.id,
                 mapped_input.id,
                 %{endpoint: "Horn.InputValue"},
                 replace?: true
               )

      assert {:error, :not_found} = VirtualJoystick.get_mapping(mapping.id)
    end

    test "updating a button binding to a vJoy-mapped input requires replacement" do
      mapped_input = button_input_fixture()
      current_input = button_input_fixture(%{pin: 4})
      element = button_element_fixture("Horn", "horn")

      assert {:ok, mapping} =
               VirtualJoystick.put_mapping(mapped_input.id, %{target_type: :button, button: 1})

      assert {:ok, binding} =
               TrainContext.create_button_binding(element.id, current_input.id, %{
                 endpoint: "Horn.InputValue"
               })

      assert {:error, :destination_conflict} =
               TrainContext.update_button_binding(binding, %{input_id: mapped_input.id})

      assert {:ok, updated} =
               TrainContext.update_button_binding(binding, %{input_id: mapped_input.id},
                 replace?: true
               )

      assert updated.input_id == mapped_input.id
      assert {:error, :not_found} = VirtualJoystick.get_mapping(mapping.id)
    end

    test "keeps simulator bindings when a replacement mapping is invalid" do
      input = analog_input_fixture()
      config = lever_config_fixture("Throttle", "throttle")

      assert {:ok, binding} = TrainContext.bind_input(config.id, input.id)

      assert {:error, _changeset} =
               VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :pov},
                 replace?: true
               )

      assert {:ok, retained} = TrainContext.get_binding(config.id)
      assert retained.id == binding.id
    end

    test "keeps a vJoy mapping when a replacement button binding is invalid" do
      input = button_input_fixture()
      element = button_element_fixture("Horn", "horn")

      assert {:ok, mapping} =
               VirtualJoystick.put_mapping(input.id, %{target_type: :button, button: 1})

      assert {:error, _changeset} =
               TrainContext.create_button_binding(element.id, input.id, %{}, replace?: true)

      assert {:ok, retained} = VirtualJoystick.get_mapping(mapping.id)
      assert retained.id == mapping.id
    end

    test "enabling an inactive lever binding mapped to vJoy requires replacement" do
      input = analog_input_fixture()
      config = lever_config_fixture("Throttle", "throttle")

      assert {:ok, mapping} =
               VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :x})

      assert {:ok, _binding} =
               Repo.insert(
                 LeverInputBinding.changeset(%LeverInputBinding{}, %{
                   lever_config_id: config.id,
                   input_id: input.id,
                   enabled: false
                 })
               )

      assert {:error, :destination_conflict} = TrainContext.set_binding_enabled(config.id, true)
      assert {:ok, inactive} = TrainContext.get_binding(config.id)
      assert inactive.enabled == false

      assert {:ok, enabled} = TrainContext.set_binding_enabled(config.id, true, replace?: true)
      assert enabled.enabled == true
      assert {:error, :not_found} = VirtualJoystick.get_mapping(mapping.id)
    end
  end

  defp lever_config_fixture(name, identifier) do
    {:ok, train} = TrainContext.create_train(%{name: name, identifier: identifier})
    {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

    {:ok, config} =
      TrainContext.create_lever_config(element.id, %{
        min_endpoint: "Throttle.MinValue",
        max_endpoint: "Throttle.MaxValue",
        value_endpoint: "Throttle.InputValue"
      })

    config
  end

  defp button_element_fixture(name, identifier) do
    {:ok, train} = TrainContext.create_train(%{name: name, identifier: identifier})
    {:ok, element} = TrainContext.create_element(train.id, %{name: name, type: :button})
    element
  end
end
