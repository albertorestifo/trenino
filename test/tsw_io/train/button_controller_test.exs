defmodule TswIo.Train.ButtonControllerTest do
  use TswIo.DataCase, async: false

  alias TswIo.Hardware
  alias TswIo.Train, as: TrainContext
  alias TswIo.Train.ButtonController

  # These tests run the ButtonController in isolation
  # They test the state management and binding loading logic

  describe "get_state/0" do
    setup do
      # Start the ButtonController for this test
      start_supervised!(ButtonController)
      :ok
    end

    test "returns initial state with no active train" do
      state = ButtonController.get_state()

      assert state.active_train == nil
      assert state.binding_lookup == %{}
      assert state.last_sent_values == %{}
    end
  end

  describe "reload_bindings/0" do
    setup do
      start_supervised!(ButtonController)

      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      {:ok, _binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue",
          on_value: 1.0,
          off_value: 0.0
        })

      %{train: train, input: input, element: element}
    end

    test "does nothing when no active train" do
      # No active train, reload should be a no-op
      assert :ok = ButtonController.reload_bindings()

      state = ButtonController.get_state()
      assert state.binding_lookup == %{}
    end

    test "reloads bindings when train is active", %{train: train, input: input} do
      # Simulate train activation by sending the message directly
      send(Process.whereis(ButtonController), {:train_changed, train})

      # Allow message processing
      Process.sleep(50)

      state = ButtonController.get_state()

      assert state.active_train.id == train.id
      assert Map.has_key?(state.binding_lookup, input.id)
    end
  end

  describe "train detection handling" do
    setup do
      start_supervised!(ButtonController)

      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      {:ok, _binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      %{train: train, input: input}
    end

    test "loads bindings when train is activated", %{train: train, input: input} do
      # Simulate train activation
      send(Process.whereis(ButtonController), {:train_changed, train})
      Process.sleep(50)

      state = ButtonController.get_state()

      assert state.active_train.id == train.id
      assert Map.has_key?(state.binding_lookup, input.id)

      binding_info = state.binding_lookup[input.id]
      assert binding_info.endpoint == "CurrentDrivableActor/Horn.InputValue"
      assert binding_info.on_value == 1.0
      assert binding_info.off_value == 0.0
    end

    test "clears bindings when train is deactivated", %{train: train} do
      # Activate train
      send(Process.whereis(ButtonController), {:train_changed, train})
      Process.sleep(50)

      # Verify train is active
      state = ButtonController.get_state()
      assert state.active_train != nil

      # Deactivate train
      send(Process.whereis(ButtonController), {:train_changed, nil})
      Process.sleep(50)

      state = ButtonController.get_state()
      assert state.active_train == nil
      assert state.binding_lookup == %{}
      assert state.last_sent_values == %{}
    end

    test "only loads enabled bindings", %{train: train, input: input} do
      # Disable the binding
      TrainContext.set_button_binding_enabled(
        (TrainContext.list_button_elements(train.id) |> hd()).id,
        false
      )

      # Activate train
      send(Process.whereis(ButtonController), {:train_changed, train})
      Process.sleep(50)

      state = ButtonController.get_state()

      # Should not have the binding since it's disabled
      refute Map.has_key?(state.binding_lookup, input.id)
    end
  end

  describe "binding with custom values" do
    setup do
      start_supervised!(ButtonController)

      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      {:ok, _binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue",
          on_value: 100.0,
          off_value: -50.0
        })

      %{train: train, input: input}
    end

    test "stores custom on/off values in binding lookup", %{train: train, input: input} do
      # Activate train
      send(Process.whereis(ButtonController), {:train_changed, train})
      Process.sleep(50)

      state = ButtonController.get_state()
      binding_info = state.binding_lookup[input.id]

      assert binding_info.on_value == 100.0
      assert binding_info.off_value == -50.0
    end
  end
end
