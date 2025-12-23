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
      # Button inputs use {input_id, nil} as key (nil virtual_pin)
      assert Map.has_key?(state.binding_lookup, {input.id, nil})
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
      # Button inputs use {input_id, nil} as key (nil virtual_pin)
      assert Map.has_key?(state.binding_lookup, {input.id, nil})

      binding_info = state.binding_lookup[{input.id, nil}]
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
      # Button inputs use {input_id, nil} as key (nil virtual_pin)
      refute Map.has_key?(state.binding_lookup, {input.id, nil})
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
      # Button inputs use {input_id, nil} as key (nil virtual_pin)
      binding_info = state.binding_lookup[{input.id, nil}]

      assert binding_info.on_value == 100.0
      assert binding_info.off_value == -50.0
    end
  end

  describe "mode and hardware_type fields" do
    setup do
      start_supervised!(ButtonController)

      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      %{train: train, element: element, input: input}
    end

    test "simple mode binding includes mode field", %{
      train: train,
      element: element,
      input: input
    } do
      {:ok, _binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue",
          mode: :simple
        })

      send(Process.whereis(ButtonController), {:train_changed, train})
      Process.sleep(50)

      state = ButtonController.get_state()
      binding_info = state.binding_lookup[{input.id, nil}]

      assert binding_info.mode == :simple
      assert binding_info.hardware_type == :momentary
    end

    test "momentary mode binding includes mode and repeat_interval_ms", %{
      train: train,
      element: element,
      input: input
    } do
      {:ok, _binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue",
          mode: :momentary,
          repeat_interval_ms: 200
        })

      send(Process.whereis(ButtonController), {:train_changed, train})
      Process.sleep(50)

      state = ButtonController.get_state()
      binding_info = state.binding_lookup[{input.id, nil}]

      assert binding_info.mode == :momentary
      assert binding_info.repeat_interval_ms == 200
    end

    test "latching hardware_type is stored correctly", %{
      train: train,
      element: element,
      input: input
    } do
      {:ok, _binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Lights.InputValue",
          hardware_type: :latching
        })

      send(Process.whereis(ButtonController), {:train_changed, train})
      Process.sleep(50)

      state = ButtonController.get_state()
      binding_info = state.binding_lookup[{input.id, nil}]

      assert binding_info.hardware_type == :latching
    end
  end

  describe "momentary mode" do
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
          mode: :momentary,
          repeat_interval_ms: 50,
          on_value: 1.0,
          off_value: 0.0
        })

      # Activate train
      send(Process.whereis(ButtonController), {:train_changed, train})
      Process.sleep(50)

      # Inject input_lookup mapping since we don't have actual serial connections
      :sys.replace_state(Process.whereis(ButtonController), fn state ->
        %{state | input_lookup: Map.put(state.input_lookup, {"COM1", 5}, input.id)}
      end)

      %{train: train, element: element, input: input}
    end

    test "tracks active button when pressed", %{element: element} do
      state = ButtonController.get_state()
      assert state.active_buttons == %{}

      # Simulate button press
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 5, 1})
      Process.sleep(20)

      state = ButtonController.get_state()
      assert Map.has_key?(state.active_buttons, element.id)
      assert state.active_buttons[element.id].timer_ref != nil
    end

    test "clears active button when released", %{element: element} do
      # Press button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 5, 1})
      Process.sleep(20)

      state = ButtonController.get_state()
      assert Map.has_key?(state.active_buttons, element.id)

      # Release button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 5, 0})
      Process.sleep(20)

      state = ButtonController.get_state()
      refute Map.has_key?(state.active_buttons, element.id)
    end

    test "timer is cancelled on button release", %{element: element} do
      # Press button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 5, 1})
      Process.sleep(20)

      state = ButtonController.get_state()
      timer_ref = state.active_buttons[element.id].timer_ref

      # Release button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 5, 0})
      Process.sleep(20)

      # Timer should be cancelled (returns false if already cancelled)
      assert Process.cancel_timer(timer_ref) == false
    end

    test "cancels active buttons on train change", %{element: element} do
      # Press button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 5, 1})
      Process.sleep(20)

      state = ButtonController.get_state()
      assert Map.has_key?(state.active_buttons, element.id)

      # Change train (deactivate)
      send(Process.whereis(ButtonController), {:train_changed, nil})
      Process.sleep(20)

      state = ButtonController.get_state()
      assert state.active_buttons == %{}
    end

    test "cancels active buttons on reload_bindings", %{train: train, element: element} do
      # Press button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 5, 1})
      Process.sleep(20)

      state = ButtonController.get_state()
      assert Map.has_key?(state.active_buttons, element.id)
      timer_ref = state.active_buttons[element.id].timer_ref

      # Reload bindings
      ButtonController.reload_bindings()
      Process.sleep(50)

      state = ButtonController.get_state()
      # Active buttons should be cleared
      assert state.active_buttons == %{}
      # Old timer should be cancelled
      assert Process.cancel_timer(timer_ref) == false
      # Train should still be active
      assert state.active_train.id == train.id
    end

    test "ignores stale momentary_repeat messages after release", %{element: element} do
      # Press button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 5, 1})
      Process.sleep(20)

      # Release button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 5, 0})
      Process.sleep(20)

      # Send a stale momentary_repeat message (shouldn't crash)
      send(Process.whereis(ButtonController), {:momentary_repeat, element.id})
      Process.sleep(20)

      # Controller should still be running
      state = ButtonController.get_state()
      refute Map.has_key?(state.active_buttons, element.id)
    end
  end

  describe "simple mode (default)" do
    setup do
      start_supervised!(ButtonController)

      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Light", type: :button})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 10, input_type: :button, debounce: 20})

      {:ok, _binding} =
        TrainContext.create_button_binding(element.id, input.id, %{
          endpoint: "CurrentDrivableActor/Light.InputValue",
          mode: :simple,
          on_value: 1.0,
          off_value: 0.0
        })

      # Activate train
      send(Process.whereis(ButtonController), {:train_changed, train})
      Process.sleep(50)

      # Inject input_lookup mapping since we don't have actual serial connections
      :sys.replace_state(Process.whereis(ButtonController), fn state ->
        %{state | input_lookup: Map.put(state.input_lookup, {"COM1", 10}, input.id)}
      end)

      %{train: train, element: element, input: input}
    end

    test "does not create active button entry when pressed", %{element: element} do
      # Simulate button press
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 10, 1})
      Process.sleep(20)

      state = ButtonController.get_state()
      # Simple mode should NOT track active buttons (no timer needed)
      refute Map.has_key?(state.active_buttons, element.id)
    end

    test "updates last_sent_values on press and release", %{element: element} do
      # Press button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 10, 1})
      Process.sleep(20)

      state = ButtonController.get_state()
      assert state.last_sent_values[element.id] == 1.0

      # Release button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 10, 0})
      Process.sleep(20)

      state = ButtonController.get_state()
      assert state.last_sent_values[element.id] == 0.0
    end
  end

  describe "sequence mode" do
    setup do
      start_supervised!(ButtonController)

      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Door", type: :button})
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 15, input_type: :button, debounce: 20})

      # Create sequences
      {:ok, on_sequence} = TrainContext.create_sequence(train.id, %{name: "Door Open"})

      TrainContext.set_sequence_commands(on_sequence, [
        %{endpoint: "DoorKey.InputValue", value: 1.0, delay_ms: 10},
        %{endpoint: "DoorOpen.InputValue", value: 1.0, delay_ms: 0}
      ])

      {:ok, off_sequence} = TrainContext.create_sequence(train.id, %{name: "Door Close"})

      TrainContext.set_sequence_commands(off_sequence, [
        %{endpoint: "DoorClose.InputValue", value: 1.0, delay_ms: 0}
      ])

      %{
        train: train,
        element: element,
        input: input,
        on_sequence: on_sequence,
        off_sequence: off_sequence
      }
    end

    test "loads sequence info with binding", ctx do
      {:ok, _binding} =
        TrainContext.create_button_binding(ctx.element.id, ctx.input.id, %{
          mode: :sequence,
          on_sequence_id: ctx.on_sequence.id
        })

      send(Process.whereis(ButtonController), {:train_changed, ctx.train})
      Process.sleep(50)

      state = ButtonController.get_state()
      binding_info = state.binding_lookup[{ctx.input.id, nil}]

      assert binding_info.mode == :sequence
      assert binding_info.on_sequence != nil
      assert binding_info.on_sequence.id == ctx.on_sequence.id
      assert length(binding_info.on_sequence.commands) == 2
    end

    test "loads off_sequence for latching hardware", ctx do
      {:ok, _binding} =
        TrainContext.create_button_binding(ctx.element.id, ctx.input.id, %{
          mode: :sequence,
          hardware_type: :latching,
          on_sequence_id: ctx.on_sequence.id,
          off_sequence_id: ctx.off_sequence.id
        })

      send(Process.whereis(ButtonController), {:train_changed, ctx.train})
      Process.sleep(50)

      state = ButtonController.get_state()
      binding_info = state.binding_lookup[{ctx.input.id, nil}]

      assert binding_info.off_sequence != nil
      assert binding_info.off_sequence.id == ctx.off_sequence.id
    end

    test "tracks active button during sequence execution", ctx do
      {:ok, _binding} =
        TrainContext.create_button_binding(ctx.element.id, ctx.input.id, %{
          mode: :sequence,
          on_sequence_id: ctx.on_sequence.id
        })

      send(Process.whereis(ButtonController), {:train_changed, ctx.train})
      Process.sleep(50)

      :sys.replace_state(Process.whereis(ButtonController), fn state ->
        %{state | input_lookup: Map.put(state.input_lookup, {"COM1", 15}, ctx.input.id)}
      end)

      # Press button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 15, 1})
      Process.sleep(5)

      state = ButtonController.get_state()
      assert Map.has_key?(state.active_buttons, ctx.element.id)
      assert state.active_buttons[ctx.element.id].sequence_task != nil
    end

    test "clears active button when sequence completes", ctx do
      {:ok, _binding} =
        TrainContext.create_button_binding(ctx.element.id, ctx.input.id, %{
          mode: :sequence,
          on_sequence_id: ctx.on_sequence.id
        })

      send(Process.whereis(ButtonController), {:train_changed, ctx.train})
      Process.sleep(50)

      :sys.replace_state(Process.whereis(ButtonController), fn state ->
        %{state | input_lookup: Map.put(state.input_lookup, {"COM1", 15}, ctx.input.id)}
      end)

      # Press button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 15, 1})

      # Wait for sequence to complete (10ms delay + buffer)
      Process.sleep(50)

      state = ButtonController.get_state()
      refute Map.has_key?(state.active_buttons, ctx.element.id)
    end

    test "cancels sequence on button release for momentary hardware", ctx do
      {:ok, _binding} =
        TrainContext.create_button_binding(ctx.element.id, ctx.input.id, %{
          mode: :sequence,
          hardware_type: :momentary,
          on_sequence_id: ctx.on_sequence.id
        })

      send(Process.whereis(ButtonController), {:train_changed, ctx.train})
      Process.sleep(50)

      :sys.replace_state(Process.whereis(ButtonController), fn state ->
        %{state | input_lookup: Map.put(state.input_lookup, {"COM1", 15}, ctx.input.id)}
      end)

      # Press button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 15, 1})
      Process.sleep(5)

      state = ButtonController.get_state()
      task_pid = state.active_buttons[ctx.element.id].sequence_task

      # Release button before sequence completes
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 15, 0})
      Process.sleep(10)

      # Task should be killed
      refute Process.alive?(task_pid)

      state = ButtonController.get_state()
      refute Map.has_key?(state.active_buttons, ctx.element.id)
    end

    test "skips when no on_sequence configured", ctx do
      # Create binding with sequence, then we'll remove the sequence info to test the nil case
      {:ok, _binding} =
        TrainContext.create_button_binding(ctx.element.id, ctx.input.id, %{
          mode: :sequence,
          on_sequence_id: ctx.on_sequence.id
        })

      send(Process.whereis(ButtonController), {:train_changed, ctx.train})
      Process.sleep(50)

      # Manually set on_sequence to nil in the binding lookup to test the nil case
      :sys.replace_state(Process.whereis(ButtonController), fn state ->
        binding_info = Map.get(state.binding_lookup, {ctx.input.id, nil})
        updated_binding = %{binding_info | on_sequence: nil}

        %{
          state
          | input_lookup: Map.put(state.input_lookup, {"COM1", 15}, ctx.input.id),
            binding_lookup: Map.put(state.binding_lookup, {ctx.input.id, nil}, updated_binding)
        }
      end)

      # Press button
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 15, 1})
      Process.sleep(20)

      # Should skip - no active button created
      state = ButtonController.get_state()
      refute Map.has_key?(state.active_buttons, ctx.element.id)
    end

    test "rapid button presses properly cancel previous sequences", ctx do
      {:ok, _binding} =
        TrainContext.create_button_binding(ctx.element.id, ctx.input.id, %{
          mode: :sequence,
          hardware_type: :momentary,
          on_sequence_id: ctx.on_sequence.id
        })

      send(Process.whereis(ButtonController), {:train_changed, ctx.train})
      Process.sleep(50)

      :sys.replace_state(Process.whereis(ButtonController), fn state ->
        %{state | input_lookup: Map.put(state.input_lookup, {"COM1", 15}, ctx.input.id)}
      end)

      # Press button (starts sequence)
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 15, 1})
      Process.sleep(5)

      state = ButtonController.get_state()
      first_task_pid = state.active_buttons[ctx.element.id].sequence_task

      # Release and immediately press again before first completes
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 15, 0})
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 15, 1})
      Process.sleep(5)

      # First task should be killed
      refute Process.alive?(first_task_pid)

      # New task should be running
      state = ButtonController.get_state()
      assert Map.has_key?(state.active_buttons, ctx.element.id)
      second_task_pid = state.active_buttons[ctx.element.id].sequence_task
      assert Process.alive?(second_task_pid)
    end

    test "sequence task is cancelled on train change", ctx do
      {:ok, _binding} =
        TrainContext.create_button_binding(ctx.element.id, ctx.input.id, %{
          mode: :sequence,
          on_sequence_id: ctx.on_sequence.id
        })

      send(Process.whereis(ButtonController), {:train_changed, ctx.train})
      Process.sleep(50)

      :sys.replace_state(Process.whereis(ButtonController), fn state ->
        %{state | input_lookup: Map.put(state.input_lookup, {"COM1", 15}, ctx.input.id)}
      end)

      # Press button to start sequence
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 15, 1})
      Process.sleep(5)

      state = ButtonController.get_state()
      task_pid = state.active_buttons[ctx.element.id].sequence_task
      assert Process.alive?(task_pid)

      # Change train (deactivate)
      send(Process.whereis(ButtonController), {:train_changed, nil})
      Process.sleep(20)

      # Task should be killed
      refute Process.alive?(task_pid)

      state = ButtonController.get_state()
      assert state.active_buttons == %{}
    end

    test "sequence with long delays is properly cancelled", ctx do
      # Create a sequence with a long delay
      {:ok, long_sequence} = TrainContext.create_sequence(ctx.train.id, %{name: "Long Delay"})

      TrainContext.set_sequence_commands(long_sequence, [
        %{endpoint: "First.InputValue", value: 1.0, delay_ms: 5000},
        %{endpoint: "Second.InputValue", value: 1.0, delay_ms: 0}
      ])

      {:ok, _binding} =
        TrainContext.create_button_binding(ctx.element.id, ctx.input.id, %{
          mode: :sequence,
          hardware_type: :momentary,
          on_sequence_id: long_sequence.id
        })

      send(Process.whereis(ButtonController), {:train_changed, ctx.train})
      Process.sleep(50)

      :sys.replace_state(Process.whereis(ButtonController), fn state ->
        %{state | input_lookup: Map.put(state.input_lookup, {"COM1", 15}, ctx.input.id)}
      end)

      # Press button to start sequence with long delay
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 15, 1})
      Process.sleep(10)

      state = ButtonController.get_state()
      task_pid = state.active_buttons[ctx.element.id].sequence_task
      assert Process.alive?(task_pid)

      # Release button - should cancel immediately, not wait for 5000ms delay
      send(Process.whereis(ButtonController), {:input_value_updated, "COM1", 15, 0})
      Process.sleep(20)

      # Task should be killed immediately
      refute Process.alive?(task_pid)

      state = ButtonController.get_state()
      refute Map.has_key?(state.active_buttons, ctx.element.id)
    end

    test "ignores stale sequence_complete messages", ctx do
      {:ok, _binding} =
        TrainContext.create_button_binding(ctx.element.id, ctx.input.id, %{
          mode: :sequence,
          on_sequence_id: ctx.on_sequence.id
        })

      send(Process.whereis(ButtonController), {:train_changed, ctx.train})
      Process.sleep(50)

      # Send a stale sequence_complete message (for an element not in active_buttons)
      send(Process.whereis(ButtonController), {:sequence_complete, 999_999})
      Process.sleep(10)

      # Controller should still be running and not crash
      state = ButtonController.get_state()
      assert state.active_train.id == ctx.train.id
    end
  end
end
