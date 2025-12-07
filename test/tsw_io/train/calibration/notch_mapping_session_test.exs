defmodule TswIo.Train.Calibration.NotchMappingSessionTest do
  use TswIo.DataCase, async: false

  alias TswIo.Hardware
  alias TswIo.Train
  alias TswIo.Train.Calibration.NotchMappingSession

  # Helper to create test fixtures
  defp create_fixtures(_context) do
    # Create hardware device and input with calibration
    {:ok, device} = Hardware.create_device(%{name: "Test Device"})

    {:ok, input} =
      Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

    {:ok, _calibration} =
      Hardware.save_calibration(input.id, %{
        min_value: 100,
        max_value: 900,
        max_hardware_value: 1023,
        is_inverted: false,
        has_rollover: false
      })

    # Reload input with calibration
    {:ok, input} = Hardware.get_input(input.id, preload: [:calibration])

    # Create train with lever config and notches
    {:ok, train} =
      Train.create_train(%{
        name: "Test Train",
        identifier: "Test_Train_#{System.unique_integer([:positive])}"
      })

    {:ok, element} =
      Train.create_element(train.id, %{
        name: "Throttle",
        type: :lever
      })

    {:ok, lever_config} =
      Train.create_lever_config(element.id, %{
        min_endpoint: "Throttle.Min",
        max_endpoint: "Throttle.Max",
        value_endpoint: "Throttle.Value",
        notch_count_endpoint: "Throttle.NotchCount",
        notch_index_endpoint: "Throttle.NotchIndex"
      })

    # Add notches
    {:ok, lever_config} =
      Train.save_notches(lever_config, [
        %{type: :gate, value: -1.0, description: "Reverse"},
        %{type: :gate, value: 0.0, description: "Neutral"},
        %{type: :gate, value: 1.0, description: "Forward"}
      ])

    %{
      device: device,
      input: input,
      train: train,
      element: element,
      lever_config: lever_config,
      calibration: input.calibration
    }
  end

  defp start_session(%{lever_config: lever_config, calibration: calibration}) do
    {:ok, pid} =
      NotchMappingSession.start_link(
        lever_config: lever_config,
        port: "/dev/test",
        pin: 5,
        calibration: calibration
      )

    pid
  end

  describe "session initialization" do
    setup [:create_fixtures]

    test "starts with :ready step", context do
      pid = start_session(context)

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == :ready
      assert state.lever_config_id == context.lever_config.id

      NotchMappingSession.cancel(pid)
    end

    test "calculates correct boundary count for notches", context do
      pid = start_session(context)

      state = NotchMappingSession.get_public_state(pid)
      # 3 notches = 4 boundaries
      assert state.notch_count == 3
      assert state.boundary_count == 4

      NotchMappingSession.cancel(pid)
    end

    test "initializes captured_boundaries with nils", context do
      pid = start_session(context)

      state = NotchMappingSession.get_public_state(pid)
      assert state.captured_boundaries == [nil, nil, nil, nil]

      NotchMappingSession.cancel(pid)
    end

    test "extracts notch descriptions", context do
      pid = start_session(context)

      state = NotchMappingSession.get_public_state(pid)
      assert state.notch_descriptions == ["Reverse", "Neutral", "Forward"]

      NotchMappingSession.cancel(pid)
    end
  end

  describe "step progression" do
    setup [:create_fixtures]

    test "can start mapping from ready step", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == {:mapping_boundary, 0}

      NotchMappingSession.cancel(pid)
    end

    test "cannot start mapping from non-ready step", context do
      pid = start_session(context)

      # Start mapping first
      assert :ok = NotchMappingSession.start_mapping(pid)

      # Try to start again
      assert {:error, :invalid_step} = NotchMappingSession.start_mapping(pid)

      NotchMappingSession.cancel(pid)
    end

    test "cannot capture boundary without enough stable samples", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Try to capture without any samples
      assert {:error, :unstable_value} = NotchMappingSession.capture_boundary(pid)

      NotchMappingSession.cancel(pid)
    end

    test "can capture boundary with stable samples", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Send stable samples (value 500 = normalized ~0.5)
      for _ <- 1..10 do
        send(pid, {:input_value_updated, "/dev/test", 5, 500})
      end

      :timer.sleep(20)

      # Should be able to capture now
      assert :ok = NotchMappingSession.capture_boundary(pid)

      state = NotchMappingSession.get_public_state(pid)
      # Should have moved to boundary 1
      assert state.current_step == {:mapping_boundary, 1}
      # First boundary should be captured
      assert hd(state.captured_boundaries) != nil

      NotchMappingSession.cancel(pid)
    end

    test "progresses through all boundaries to preview", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Capture all 4 boundaries
      for boundary_value <- [100, 350, 600, 900] do
        for _ <- 1..10 do
          send(pid, {:input_value_updated, "/dev/test", 5, boundary_value})
        end

        :timer.sleep(20)
        assert :ok = NotchMappingSession.capture_boundary(pid)
      end

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == :preview
      assert state.all_captured == true

      NotchMappingSession.cancel(pid)
    end
  end

  describe "sample collection" do
    setup [:create_fixtures]

    test "tracks current value from input", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      send(pid, {:input_value_updated, "/dev/test", 5, 500})
      :timer.sleep(10)

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_value != nil

      NotchMappingSession.cancel(pid)
    end

    test "ignores samples from other pins", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Send sample for different pin
      send(pid, {:input_value_updated, "/dev/test", 6, 500})
      :timer.sleep(10)

      state = NotchMappingSession.get_public_state(pid)
      assert state.sample_count == 0

      NotchMappingSession.cancel(pid)
    end

    test "tracks sample count", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      for i <- 1..5 do
        send(pid, {:input_value_updated, "/dev/test", 5, 500})
        :timer.sleep(5)

        state = NotchMappingSession.get_public_state(pid)
        assert state.sample_count == i
      end

      NotchMappingSession.cancel(pid)
    end

    test "detects stability when samples are consistent", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Unstable samples
      state = NotchMappingSession.get_public_state(pid)
      assert state.is_stable == false

      # Send consistent samples
      for _ <- 1..10 do
        send(pid, {:input_value_updated, "/dev/test", 5, 500})
      end

      :timer.sleep(20)

      state = NotchMappingSession.get_public_state(pid)
      assert state.is_stable == true
      assert state.can_capture == true

      NotchMappingSession.cancel(pid)
    end

    test "detects instability when samples vary too much", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Send varying samples
      for value <- [100, 200, 300, 400, 500] do
        send(pid, {:input_value_updated, "/dev/test", 5, value})
      end

      :timer.sleep(20)

      state = NotchMappingSession.get_public_state(pid)
      assert state.is_stable == false
      assert state.can_capture == false

      NotchMappingSession.cancel(pid)
    end
  end

  describe "boundary navigation" do
    setup [:create_fixtures]

    test "can go to specific boundary", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Jump to boundary 2
      assert :ok = NotchMappingSession.go_to_boundary(pid, 2)

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == {:mapping_boundary, 2}

      NotchMappingSession.cancel(pid)
    end

    test "cannot go to invalid boundary index", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # 4 boundaries means valid indices are 0-3
      assert {:error, :invalid_boundary_index} = NotchMappingSession.go_to_boundary(pid, 5)

      NotchMappingSession.cancel(pid)
    end

    test "can go back to edit previous boundary", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Capture boundary 0
      for _ <- 1..10 do
        send(pid, {:input_value_updated, "/dev/test", 5, 100})
      end

      :timer.sleep(20)
      assert :ok = NotchMappingSession.capture_boundary(pid)

      # Now at boundary 1, go back to 0
      assert :ok = NotchMappingSession.go_to_boundary(pid, 0)

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == {:mapping_boundary, 0}

      NotchMappingSession.cancel(pid)
    end
  end

  describe "preview and save" do
    setup [:create_fixtures]

    test "cannot go to preview without all boundaries captured", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Only capture one boundary
      for _ <- 1..10 do
        send(pid, {:input_value_updated, "/dev/test", 5, 100})
      end

      :timer.sleep(20)
      assert :ok = NotchMappingSession.capture_boundary(pid)

      # Try to go to preview
      assert {:error, :incomplete_boundaries} = NotchMappingSession.go_to_preview(pid)

      NotchMappingSession.cancel(pid)
    end

    test "can go to preview with all boundaries captured", context do
      pid = start_session(context)

      # Allow database access for the session process
      Ecto.Adapters.SQL.Sandbox.allow(TswIo.Repo, self(), pid)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Capture all 4 boundaries
      for boundary_value <- [100, 350, 600, 900] do
        for _ <- 1..10 do
          send(pid, {:input_value_updated, "/dev/test", 5, boundary_value})
        end

        :timer.sleep(20)
        assert :ok = NotchMappingSession.capture_boundary(pid)
      end

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == :preview

      NotchMappingSession.cancel(pid)
    end

    test "saves notch input ranges on save", context do
      pid = start_session(context)

      # Allow database access for the session process
      Ecto.Adapters.SQL.Sandbox.allow(TswIo.Repo, self(), pid)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Capture all 4 boundaries
      for boundary_value <- [100, 350, 600, 900] do
        for _ <- 1..10 do
          send(pid, {:input_value_updated, "/dev/test", 5, boundary_value})
        end

        :timer.sleep(20)
        assert :ok = NotchMappingSession.capture_boundary(pid)
      end

      # Now in preview, save
      assert :ok = NotchMappingSession.save_mapping(pid)

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == :complete
      assert match?({:ok, _}, state.result)

      # Verify notches were updated in database
      {:ok, updated_config} = Train.get_lever_config(context.element.id)
      notches = Enum.sort_by(updated_config.notches, & &1.index)

      # Each notch should have input ranges set
      assert Enum.all?(notches, fn notch ->
               notch.input_min != nil and notch.input_max != nil
             end)
    end
  end

  describe "PubSub events" do
    setup [:create_fixtures]

    test "broadcasts session_started on init", context do
      NotchMappingSession.subscribe(context.lever_config.id)

      pid = start_session(context)

      assert_receive {:session_started, state}
      assert state.lever_config_id == context.lever_config.id
      assert state.current_step == :ready

      NotchMappingSession.cancel(pid)
    end

    test "broadcasts step_changed on step transitions", context do
      NotchMappingSession.subscribe(context.lever_config.id)

      pid = start_session(context)

      # Clear session_started
      assert_receive {:session_started, _}

      NotchMappingSession.start_mapping(pid)
      assert_receive {:step_changed, state}
      assert state.current_step == {:mapping_boundary, 0}

      NotchMappingSession.cancel(pid)
    end

    test "broadcasts sample_updated on input values", context do
      NotchMappingSession.subscribe(context.lever_config.id)

      pid = start_session(context)

      # Clear session_started
      assert_receive {:session_started, _}

      NotchMappingSession.start_mapping(pid)
      assert_receive {:step_changed, _}

      send(pid, {:input_value_updated, "/dev/test", 5, 500})
      assert_receive {:sample_updated, state}
      assert state.current_value != nil

      NotchMappingSession.cancel(pid)
    end

    test "broadcasts mapping_result on completion", context do
      NotchMappingSession.subscribe(context.lever_config.id)

      pid = start_session(context)

      # Allow database access
      Ecto.Adapters.SQL.Sandbox.allow(TswIo.Repo, self(), pid)

      # Clear initial messages
      flush_mailbox()

      NotchMappingSession.start_mapping(pid)
      flush_mailbox()

      # Capture all boundaries
      for boundary_value <- [100, 350, 600, 900] do
        for _ <- 1..10 do
          send(pid, {:input_value_updated, "/dev/test", 5, boundary_value})
        end

        :timer.sleep(20)
        NotchMappingSession.capture_boundary(pid)
        flush_mailbox()
      end

      # Save
      NotchMappingSession.save_mapping(pid)

      assert_receive {:mapping_result, {:ok, _updated_config}}, 1000
    end
  end

  describe "cancellation" do
    setup [:create_fixtures]

    test "cancel stops the session", context do
      pid = start_session(context)

      assert Process.alive?(pid)

      NotchMappingSession.cancel(pid)
      :timer.sleep(10)

      refute Process.alive?(pid)
    end
  end

  # Helper to flush all messages from mailbox
  defp flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      0 -> :ok
    end
  end
end
