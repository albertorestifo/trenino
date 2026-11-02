defmodule Trenino.Train.Calibration.NotchMappingSessionTest do
  # async: false because the test uses Sandbox.allow/3 to grant DB access
  # to spawned NotchMappingSession processes — that API requires the shared
  # Sandbox pool, not the dynamic isolated Repo used for async tests.
  use Trenino.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Hardware
  alias Trenino.Train
  alias Trenino.Train.Calibration.NotchMappingSession
  alias Trenino.Train.LeverMapper

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
        identifiers: [%{identifier: "Test_Train_#{System.unique_integer([:positive])}"}]
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

    # Add notches - mix of gate and linear types
    {:ok, lever_config} =
      Train.save_notches(lever_config, [
        %{type: :gate, value: -1.0, description: "Reverse"},
        %{type: :linear, min_value: 0.0, max_value: 0.5, description: "Low"},
        %{type: :gate, value: 1.0, description: "Full"}
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

    test "calculates correct notch count", context do
      pid = start_session(context)

      state = NotchMappingSession.get_public_state(pid)
      assert state.notch_count == 3

      NotchMappingSession.cancel(pid)
    end

    test "initializes captured_ranges with nils", context do
      pid = start_session(context)

      state = NotchMappingSession.get_public_state(pid)
      assert state.captured_ranges == [nil, nil, nil]

      NotchMappingSession.cancel(pid)
    end

    test "extracts notch info including type", context do
      pid = start_session(context)

      state = NotchMappingSession.get_public_state(pid)
      notches = state.notches

      assert length(notches) == 3
      assert Enum.at(notches, 0).type == :gate
      assert Enum.at(notches, 0).description == "Reverse"
      assert Enum.at(notches, 1).type == :linear
      assert Enum.at(notches, 1).description == "Low"
      assert Enum.at(notches, 2).type == :gate
      assert Enum.at(notches, 2).description == "Full"

      NotchMappingSession.cancel(pid)
    end

    test "calculates total_travel from calibration", context do
      pid = start_session(context)

      state = NotchMappingSession.get_public_state(pid)
      # max_value (900) - min_value (100) = 800
      assert state.total_travel == 800

      NotchMappingSession.cancel(pid)
    end
  end

  describe "step progression" do
    setup [:create_fixtures]

    test "can start mapping from ready step", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == {:mapping_notch, 0}
      assert state.current_notch.description == "Reverse"

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

    test "cannot capture range without any samples", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Try to capture without any samples
      assert {:error, :no_samples} = NotchMappingSession.capture_range(pid)

      NotchMappingSession.cancel(pid)
    end

    test "can capture single point (min == max) for gate notches", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)
      assert :ok = NotchMappingSession.start_capturing(pid)

      # Send samples all with same value (single point capture)
      for _ <- 1..3 do
        send(pid, {:input_value_updated, "/dev/test", 5, 500})
      end

      :timer.sleep(20)

      # Single point capture should succeed (valid for gate notches)
      assert :ok = NotchMappingSession.capture_range(pid)

      state = NotchMappingSession.get_public_state(pid)
      # Should have moved to next notch
      assert state.current_step == {:mapping_notch, 1}
      # The captured range should have min == max
      range = hd(state.captured_ranges)
      assert range.min == range.max

      NotchMappingSession.cancel(pid)
    end

    test "can_capture is true as soon as one sample is collected", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)
      assert :ok = NotchMappingSession.start_capturing(pid)

      # Before any samples, can_capture should be false
      state = NotchMappingSession.get_public_state(pid)
      assert state.can_capture == false

      # Send a single sample
      send(pid, {:input_value_updated, "/dev/test", 5, 500})
      :timer.sleep(20)

      # After one sample, can_capture should be true
      state = NotchMappingSession.get_public_state(pid)
      assert state.can_capture == true
      assert state.sample_count == 1

      NotchMappingSession.cancel(pid)
    end

    test "can capture range with varied samples", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)
      assert :ok = NotchMappingSession.start_capturing(pid)

      # Send varied samples to create a range
      # Raw values 200-300 → calibrated 100-200
      for value <- [200, 220, 250, 280, 300, 250, 220, 280, 240, 260] do
        send(pid, {:input_value_updated, "/dev/test", 5, value})
      end

      :timer.sleep(20)

      # Should be able to capture now
      assert :ok = NotchMappingSession.capture_range(pid)

      state = NotchMappingSession.get_public_state(pid)
      # Should have moved to notch 1 (in positioning mode)
      assert state.current_step == {:mapping_notch, 1}
      assert state.is_capturing == false
      # First notch range should be captured
      assert hd(state.captured_ranges) != nil
      assert hd(state.captured_ranges).min == 100
      assert hd(state.captured_ranges).max == 200

      NotchMappingSession.cancel(pid)
    end

    test "progresses through all notches to preview", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Capture all 3 notch ranges (need at least 10 samples each with range)
      ranges = [
        # Notch 0: raw 200-300 → calibrated 100-200
        [200, 220, 240, 260, 280, 300, 250, 230, 270, 290],
        # Notch 1: raw 400-600 → calibrated 300-500
        [400, 440, 480, 520, 560, 600, 500, 450, 550, 580],
        # Notch 2: raw 700-850 → calibrated 600-750
        [700, 720, 750, 780, 810, 850, 800, 760, 830, 790]
      ]

      for range_values <- ranges do
        # Start capturing for each notch
        assert :ok = NotchMappingSession.start_capturing(pid)

        for value <- range_values do
          send(pid, {:input_value_updated, "/dev/test", 5, value})
        end

        :timer.sleep(20)
        assert :ok = NotchMappingSession.capture_range(pid)
      end

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == :preview
      assert state.all_captured == true

      NotchMappingSession.cancel(pid)
    end
  end

  describe "sample collection" do
    setup [:create_fixtures]

    test "tracks current value and min/max from input", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)
      assert :ok = NotchMappingSession.start_capturing(pid)

      # Send a few samples
      send(pid, {:input_value_updated, "/dev/test", 5, 500})
      :timer.sleep(10)

      state = NotchMappingSession.get_public_state(pid)
      # Raw 500 → calibrated 400 (500 - 100 min_value)
      assert state.current_value == 400
      assert state.current_min == 400
      assert state.current_max == 400

      # Send higher value
      send(pid, {:input_value_updated, "/dev/test", 5, 600})
      :timer.sleep(10)

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_value == 500
      assert state.current_min == 400
      assert state.current_max == 500

      NotchMappingSession.cancel(pid)
    end

    test "ignores samples from other pins", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)
      assert :ok = NotchMappingSession.start_capturing(pid)

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
      assert :ok = NotchMappingSession.start_capturing(pid)

      for i <- 1..5 do
        send(pid, {:input_value_updated, "/dev/test", 5, 500 + i})
        :timer.sleep(5)

        state = NotchMappingSession.get_public_state(pid)
        assert state.sample_count == i
      end

      NotchMappingSession.cancel(pid)
    end

    test "can reset samples to start fresh", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)
      assert :ok = NotchMappingSession.start_capturing(pid)

      # Collect some samples
      for value <- [200, 300, 400, 500, 600] do
        send(pid, {:input_value_updated, "/dev/test", 5, value})
      end

      :timer.sleep(20)

      state = NotchMappingSession.get_public_state(pid)
      assert state.sample_count == 5
      assert state.current_min == 100
      assert state.current_max == 500

      # Reset (also stops capturing)
      assert :ok = NotchMappingSession.reset_samples(pid)

      state = NotchMappingSession.get_public_state(pid)
      assert state.sample_count == 0
      assert state.current_min == nil
      assert state.current_max == nil
      assert state.is_capturing == false

      NotchMappingSession.cancel(pid)
    end
  end

  describe "notch navigation" do
    setup [:create_fixtures]

    test "can go to specific notch", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Jump to notch 2
      assert :ok = NotchMappingSession.go_to_notch(pid, 2)

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == {:mapping_notch, 2}
      assert state.current_notch.description == "Full"

      NotchMappingSession.cancel(pid)
    end

    test "cannot go to invalid notch index", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # 3 notches means valid indices are 0-2
      assert {:error, :invalid_notch_index} = NotchMappingSession.go_to_notch(pid, 5)

      NotchMappingSession.cancel(pid)
    end

    test "can go back to edit previous notch", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)
      assert :ok = NotchMappingSession.start_capturing(pid)

      # Capture notch 0
      for value <- [200, 220, 250, 280, 300, 250, 220, 280, 240, 260] do
        send(pid, {:input_value_updated, "/dev/test", 5, value})
      end

      :timer.sleep(20)
      assert :ok = NotchMappingSession.capture_range(pid)

      # Now at notch 1 (in positioning mode), go back to 0
      assert :ok = NotchMappingSession.go_to_notch(pid, 0)

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == {:mapping_notch, 0}
      # Samples should be reset when navigating
      assert state.sample_count == 0
      assert state.is_capturing == false

      NotchMappingSession.cancel(pid)
    end

    test "capturing the last notch first returns to the first uncaptured notch", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)
      assert :ok = NotchMappingSession.go_to_notch(pid, 2)
      capture_notch(pid, [800, 820, 850])

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == {:mapping_notch, 0}
      refute state.all_captured

      NotchMappingSession.cancel(pid)
    end
  end

  describe "preview and save" do
    setup [:create_fixtures]

    test "cannot go to preview without all ranges captured", context do
      pid = start_session(context)

      assert :ok = NotchMappingSession.start_mapping(pid)
      assert :ok = NotchMappingSession.start_capturing(pid)

      # Only capture one notch
      for value <- [200, 220, 250, 280, 300, 250, 220, 280, 240, 260] do
        send(pid, {:input_value_updated, "/dev/test", 5, value})
      end

      :timer.sleep(20)
      assert :ok = NotchMappingSession.capture_range(pid)

      # Try to go to preview
      assert {:error, :incomplete_ranges} = NotchMappingSession.go_to_preview(pid)

      NotchMappingSession.cancel(pid)
    end

    test "can go to preview with all ranges captured", context do
      pid = start_session(context)

      # Allow database access for the session process
      Sandbox.allow(Trenino.Repo, self(), pid)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Capture all 3 notch ranges (need at least 10 samples each)
      ranges = [
        [200, 220, 240, 260, 280, 300, 250, 230, 270, 290],
        [400, 440, 480, 520, 560, 600, 500, 450, 550, 580],
        [700, 720, 750, 780, 810, 850, 800, 760, 830, 790]
      ]

      for range_values <- ranges do
        assert :ok = NotchMappingSession.start_capturing(pid)

        for value <- range_values do
          send(pid, {:input_value_updated, "/dev/test", 5, value})
        end

        :timer.sleep(20)
        assert :ok = NotchMappingSession.capture_range(pid)
      end

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == :preview

      NotchMappingSession.cancel(pid)
    end

    test "saves notch input ranges on save", context do
      pid = start_session(context)

      # Allow database access for the session process
      Sandbox.allow(Trenino.Repo, self(), pid)

      assert :ok = NotchMappingSession.start_mapping(pid)

      # Capture all 3 notch ranges (need at least 10 samples each)
      ranges = [
        [200, 220, 240, 260, 280, 300, 250, 230, 270, 290],
        [400, 440, 480, 520, 560, 600, 500, 450, 550, 580],
        [700, 720, 750, 780, 810, 850, 800, 760, 830, 790]
      ]

      for range_values <- ranges do
        assert :ok = NotchMappingSession.start_capturing(pid)

        for value <- range_values do
          send(pid, {:input_value_updated, "/dev/test", 5, value})
        end

        :timer.sleep(20)
        assert :ok = NotchMappingSession.capture_range(pid)
      end

      # Now in preview, save
      assert :ok = NotchMappingSession.save_mapping(pid)

      state = NotchMappingSession.get_public_state(pid)
      assert state.current_step == :complete
      assert match?({:ok, _}, state.result)

      # Verify notches were updated in database
      {:ok, updated_config} = Train.get_lever_config(context.element.id)
      notches = Enum.sort_by(updated_config.notches, & &1.index)

      # Each notch should have input ranges set (normalized to 0.0-1.0)
      assert Enum.all?(notches, fn notch ->
               notch.input_min != nil and notch.input_max != nil
             end)

      # Verify ranges are in 0.0-1.0 normalized format
      first_notch = hd(notches)
      # Calibrated 100-200 out of 800 total → 0.125-0.25
      assert first_notch.input_min >= 0.0 and first_notch.input_min <= 1.0
      assert first_notch.input_max >= 0.0 and first_notch.input_max <= 1.0
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
      assert state.current_step == {:mapping_notch, 0}

      NotchMappingSession.cancel(pid)
    end

    test "broadcasts sample_updated on input values", context do
      NotchMappingSession.subscribe(context.lever_config.id)

      pid = start_session(context)

      # Clear session_started
      assert_receive {:session_started, _}

      NotchMappingSession.start_mapping(pid)
      assert_receive {:step_changed, _}

      NotchMappingSession.start_capturing(pid)
      assert_receive {:capture_started, _}

      send(pid, {:input_value_updated, "/dev/test", 5, 500})
      assert_receive {:sample_updated, state}
      assert state.current_value == 400

      NotchMappingSession.cancel(pid)
    end

    test "broadcasts mapping_result on completion", context do
      NotchMappingSession.subscribe(context.lever_config.id)

      pid = start_session(context)

      # Allow database access
      Sandbox.allow(Trenino.Repo, self(), pid)

      # Clear initial messages
      flush_mailbox()

      NotchMappingSession.start_mapping(pid)
      flush_mailbox()

      # Capture all notch ranges (need at least 10 samples each)
      ranges = [
        [200, 220, 240, 260, 280, 300, 250, 230, 270, 290],
        [400, 440, 480, 520, 560, 600, 500, 450, 550, 580],
        [700, 720, 750, 780, 810, 850, 800, 760, 830, 790]
      ]

      for range_values <- ranges do
        NotchMappingSession.start_capturing(pid)
        flush_mailbox()

        for value <- range_values do
          send(pid, {:input_value_updated, "/dev/test", 5, value})
        end

        :timer.sleep(20)
        NotchMappingSession.capture_range(pid)
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

  describe "preview" do
    setup [:create_fixtures]

    # Forward lever: hardware 0% = Braking (sim 0.0), hardware 100% = Power (sim 1.0)
    @forward_notches [
      %{
        type: :linear,
        min_value: -10.0,
        max_value: 0.0,
        sim_input_min: 0.0,
        sim_input_max: 0.45,
        description: "Braking"
      },
      %{
        type: :gate,
        value: 0.0,
        sim_input_min: 0.46,
        sim_input_max: 0.54,
        description: "Neutral"
      },
      %{
        type: :linear,
        min_value: 0.0,
        max_value: 1.0,
        sim_input_min: 0.55,
        sim_input_max: 1.0,
        description: "Power"
      }
    ]

    # Raw samples per notch (calibration 100..900 -> calibrated 0..800)
    @forward_captures [
      # Braking: calibrated 0-350
      [100, 200, 300, 450],
      # Neutral: calibrated 360-440
      [460, 500, 540],
      # Power: calibrated 450-800
      [550, 700, 900]
    ]

    # M9-A style: sim order Emergency -> Power, but physically Power sits at
    # hardware 0% and Emergency at hardware 100%.
    @reversed_notches [
      %{
        type: :gate,
        value: -1.0,
        sim_input_min: 0.0,
        sim_input_max: 0.04,
        description: "Emergency"
      },
      %{
        type: :linear,
        min_value: -10.0,
        max_value: -1.0,
        sim_input_min: 0.05,
        sim_input_max: 0.45,
        description: "Braking"
      },
      %{
        type: :gate,
        value: 0.0,
        sim_input_min: 0.46,
        sim_input_max: 0.54,
        description: "Neutral"
      },
      %{
        type: :linear,
        min_value: 0.0,
        max_value: 1.0,
        sim_input_min: 0.55,
        sim_input_max: 1.0,
        description: "Power"
      }
    ]

    @reversed_captures [
      # Emergency: calibrated 780-800
      [880, 900],
      # Braking: calibrated 400-750
      [500, 700, 850],
      # Neutral: calibrated 350-370
      [450, 470],
      # Power: calibrated 0-300
      [100, 250, 400]
    ]

    test "is :none before anything is captured", context do
      pid = start_preview_session(context, @forward_notches)

      assert %{
               status: :none,
               direction_known: false,
               inverted: false,
               low_end: nil,
               high_end: nil,
               live: nil,
               hardware_ranges: []
             } = NotchMappingSession.get_public_state(pid).preview

      NotchMappingSession.cancel(pid)
    end

    test "forward lever maps low end to sim 0 and high end to sim 1", context do
      pid = start_preview_session(context, @forward_notches)
      :ok = NotchMappingSession.start_mapping(pid)
      Enum.each(@forward_captures, &capture_notch(pid, &1))

      preview = NotchMappingSession.get_public_state(pid).preview

      assert preview.status == :ready
      assert preview.direction_known
      refute preview.inverted

      assert preview.low_end == %{
               notch_index: 0,
               description: "Braking",
               type: :linear,
               hardware_pct: +0.0,
               sim_input: +0.0
             }

      assert %{notch_index: 2, hardware_pct: 100.0, sim_input: 1.0} = preview.high_end

      assert [braking, neutral, power] = preview.hardware_ranges

      assert %{
               notch_index: 0,
               type: :linear,
               min_pct: +0.0,
               max_pct: 43.75,
               sim_at_min: +0.0,
               sim_output_min: -10.0,
               sim_output_max: +0.0
             } = braking

      assert braking.sim_at_max > braking.sim_at_min

      assert %{
               notch_index: 1,
               type: :gate,
               min_pct: 45.0,
               max_pct: 55.0,
               sim_at_min: 0.5,
               sim_at_max: 0.5,
               sim_output_min: +0.0,
               sim_output_max: +0.0
             } = neutral

      assert %{notch_index: 2, sim_at_min: 0.55, sim_at_max: 1.0} = power

      NotchMappingSession.cancel(pid)
    end

    test "inverted (M9-A style) lever is detected and maps ends correctly", context do
      pid = start_preview_session(context, @reversed_notches)
      :ok = NotchMappingSession.start_mapping(pid)
      Enum.each(@reversed_captures, &capture_notch(pid, &1))

      preview = NotchMappingSession.get_public_state(pid).preview

      assert preview.status == :ready
      assert preview.direction_known
      assert preview.inverted

      # Physical low end is Power at full, physical high end is Emergency
      assert %{notch_index: 3, description: "Power", hardware_pct: +0.0, sim_input: 1.0} =
               preview.low_end

      assert %{notch_index: 0, description: "Emergency", hardware_pct: 100.0, sim_input: 0.02} =
               preview.high_end

      # Physical order is the reverse of sim order
      assert Enum.map(preview.hardware_ranges, & &1.notch_index) == [3, 2, 1, 0]

      # sim_input decreases monotonically as the lever moves toward hardware 100%
      sims =
        Enum.flat_map(preview.hardware_ranges, fn range ->
          [range.sim_at_min, range.sim_at_max]
        end)

      assert Enum.all?(sims, &is_float/1)
      assert sims == Enum.sort(sims, :desc)

      NotchMappingSession.cancel(pid)
    end

    test "partial capture with one notch leaves direction unknown", context do
      pid = start_preview_session(context, @forward_notches)
      :ok = NotchMappingSession.start_mapping(pid)
      capture_notch(pid, Enum.at(@forward_captures, 0))

      preview = NotchMappingSession.get_public_state(pid).preview

      assert preview.status == :partial
      refute preview.direction_known
      refute preview.inverted
      assert [%{notch_index: 0}] = preview.hardware_ranges
      assert %{notch_index: 0, sim_input: +0.0} = preview.low_end

      # Hardware 100% falls in an uncaptured gap: nearest range's edge is used
      [braking] = preview.hardware_ranges
      assert %{notch_index: 0, hardware_pct: 100.0} = preview.high_end
      assert preview.high_end.sim_input == braking.sim_at_max

      NotchMappingSession.cancel(pid)
    end

    test "live reflects the current lever position", context do
      pid = start_preview_session(context, @forward_notches)
      :ok = NotchMappingSession.start_mapping(pid)
      capture_notch(pid, Enum.at(@forward_captures, 0))
      capture_notch(pid, Enum.at(@forward_captures, 1))

      # Positioning (not capturing) for Power: calibrated 200 -> 25% inside Braking
      send(pid, {:input_value_updated, "/dev/test", 5, 300})
      preview = NotchMappingSession.get_public_state(pid).preview

      assert preview.direction_known
      assert %{notch_index: 0, hardware_pct: 25.0, type: :linear} = preview.live
      # Braking stored as 0.0-0.44: 0.25 / 0.44 * 0.45
      assert preview.live.sim_input == 0.26

      # Calibrated 800 -> 100%, Power not captured yet: a gap
      send(pid, {:input_value_updated, "/dev/test", 5, 900})
      assert NotchMappingSession.get_public_state(pid).preview.live == nil

      NotchMappingSession.cancel(pid)
    end

    for {name, notches, captures} <- [
          {"forward", @forward_notches, @forward_captures},
          {"inverted", @reversed_notches, @reversed_captures}
        ] do
      test "#{name} preview matches LeverMapper on the saved config", context do
        pid = start_preview_session(context, unquote(Macro.escape(notches)))
        Sandbox.allow(Trenino.Repo, self(), pid)
        :ok = NotchMappingSession.start_mapping(pid)
        Enum.each(unquote(captures), &capture_notch(pid, &1))

        preview = NotchMappingSession.get_public_state(pid).preview
        assert :ok = NotchMappingSession.save_mapping(pid)

        {:ok, saved} = Train.get_lever_config(context.element.id)

        assert saved.inverted == preview.inverted
        assert {:ok, preview.low_end.sim_input} == LeverMapper.map_input(saved, 0.0)
        assert {:ok, preview.high_end.sim_input} == LeverMapper.map_input(saved, 1.0)

        # Gates are position independent, so their range ends are comparable directly
        for %{type: :gate} = range <- preview.hardware_ranges do
          mid = Float.round((range.min_pct + range.max_pct) / 200, 2)
          assert {:ok, range.sim_at_min} == LeverMapper.map_input(saved, mid)
        end
      end
    end
  end

  defp start_preview_session(%{lever_config: lever_config} = context, notches) do
    {:ok, lever_config} = Train.save_notches(lever_config, notches)
    start_session(%{context | lever_config: lever_config})
  end

  # GenServer calls are processed after the input messages sent before them,
  # so no sleep is needed between the sends and capture_range/1.
  defp capture_notch(pid, raw_values) do
    :ok = NotchMappingSession.start_capturing(pid)
    Enum.each(raw_values, &send(pid, {:input_value_updated, "/dev/test", 5, &1}))
    :ok = NotchMappingSession.capture_range(pid)
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
