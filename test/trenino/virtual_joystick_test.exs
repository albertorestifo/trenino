defmodule Trenino.VirtualJoystickTest do
  use Trenino.DataCase, async: true

  alias Trenino.VirtualJoystick
  alias Trenino.VirtualJoystick.{Configuration, Mapping}

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
end
