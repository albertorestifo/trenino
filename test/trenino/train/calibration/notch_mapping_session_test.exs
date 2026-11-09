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
      assert preview.live.sim_input == 0.2557

      # Calibrated 800 -> 100%, Power not captured yet: the gap resolves to the
      # nearest captured notch, as it would at runtime
      send(pid, {:input_value_updated, "/dev/test", 5, 900})

      assert %{notch_index: 1, type: :gate, sim_input: 0.5} =
               NotchMappingSession.get_public_state(pid).preview.live

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

  describe "direction override" do
    setup [:create_fixtures]

    @override_notches [
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

    @override_captures [[100, 200, 300, 450], [460, 500, 540], [550, 700, 900]]

    @single_notch [
      %{
        type: :linear,
        min_value: 0.0,
        max_value: 1.0,
        sim_input_min: 0.0,
        sim_input_max: 1.0,
        description: "Throttle"
      }
    ]

    test "defaults to auto with the detected direction", context do
      pid = start_preview_session(context, @override_notches)
      :ok = NotchMappingSession.start_mapping(pid)
      Enum.each(@override_captures, &capture_notch(pid, &1))

      state = NotchMappingSession.get_public_state(pid)
      assert state.direction_override == nil

      assert %{
               direction_source: :auto,
               direction_known: true,
               direction_detectable: true,
               detected_inverted: false,
               inverted: false
             } = state.preview

      NotchMappingSession.cancel(pid)
    end

    test "is rejected before mapping starts and for unknown directions", context do
      pid = start_preview_session(context, @override_notches)

      assert {:error, :invalid_step} = NotchMappingSession.set_direction_override(pid, :reversed)
      assert {:error, :invalid_direction} = NotchMappingSession.set_direction_override(pid, :up)

      NotchMappingSession.cancel(pid)
    end

    test "broadcasts step_changed with the updated preview", context do
      pid = start_preview_session(context, @single_notch)
      :ok = NotchMappingSession.start_mapping(pid)
      :ok = NotchMappingSession.subscribe(context.lever_config.id)

      :ok = NotchMappingSession.set_direction_override(pid, :reversed)

      assert_receive {:step_changed, %{direction_override: true, preview: preview}}
      assert %{direction_source: :manual, direction_known: true, inverted: true} = preview

      NotchMappingSession.cancel(pid)
    end

    test "is rejected once the direction is detectable, in preview and save", context do
      pid = start_preview_session(context, @override_notches)
      Sandbox.allow(Trenino.Repo, self(), pid)
      :ok = NotchMappingSession.start_mapping(pid)
      Enum.each(@override_captures, &capture_notch(pid, &1))

      auto = NotchMappingSession.get_public_state(pid).preview

      assert {:error, :not_overridable} =
               NotchMappingSession.set_direction_override(pid, :reversed)

      state = NotchMappingSession.get_public_state(pid)

      assert state.direction_override == nil
      assert state.preview == auto

      assert %{
               direction_source: :auto,
               direction_detectable: true,
               direction_overridable: false,
               inverted: false
             } = auto

      assert :ok = NotchMappingSession.save_mapping(pid)
      {:ok, saved} = Train.get_lever_config(context.element.id)

      assert saved.inverted == false
      assert {:ok, auto.low_end.sim_input} == LeverMapper.map_input(saved, 0.0)
      assert {:ok, auto.high_end.sim_input} == LeverMapper.map_input(saved, 1.0)
    end

    test "detection is used on an inverted lever and :same is rejected", context do
      notches = [
        %{type: :gate, value: 0.0, sim_input_min: 0.0, sim_input_max: 0.1, description: "Off"},
        %{type: :gate, value: 1.0, sim_input_min: 0.9, sim_input_max: 1.0, description: "On"}
      ]

      pid = start_preview_session(context, notches)
      Sandbox.allow(Trenino.Repo, self(), pid)
      :ok = NotchMappingSession.start_mapping(pid)
      # Off captured at the high end, On at the low end: detected inverted
      capture_notch(pid, [880, 900])
      capture_notch(pid, [100, 120])

      assert {:error, :not_overridable} = NotchMappingSession.set_direction_override(pid, :same)
      preview = NotchMappingSession.get_public_state(pid).preview

      assert %{direction_source: :auto, detected_inverted: true, inverted: true} = preview

      assert :ok = NotchMappingSession.save_mapping(pid)
      {:ok, saved} = Train.get_lever_config(context.element.id)
      assert saved.inverted == true
    end

    test "multi-notch lever in partial capture is not overridable", context do
      pid = start_preview_session(context, @override_notches)
      :ok = NotchMappingSession.start_mapping(pid)
      :ok = NotchMappingSession.subscribe(context.lever_config.id)

      assert {:error, :not_overridable} =
               NotchMappingSession.set_direction_override(pid, :reversed)

      capture_notch(pid, Enum.at(@override_captures, 0))
      flush_mailbox()

      assert %{
               status: :partial,
               direction_known: false,
               direction_detectable: false,
               direction_pending: true,
               direction_overridable: false,
               direction_source: :auto,
               inverted: false
             } = NotchMappingSession.get_public_state(pid).preview

      for direction <- [:same, :reversed, :auto] do
        assert {:error, :not_overridable} =
                 NotchMappingSession.set_direction_override(pid, direction)
      end

      assert NotchMappingSession.get_state(pid).direction_override == nil
      refute_received {:step_changed, _}

      # The second capture makes it detectable
      capture_notch(pid, Enum.at(@override_captures, 1))

      assert %{direction_known: true, direction_detectable: true, direction_overridable: false} =
               NotchMappingSession.get_public_state(pid).preview

      NotchMappingSession.cancel(pid)
    end

    test "single-gate lever is not overridable", context do
      gate = [
        %{type: :gate, value: 0.0, sim_input_min: 0.4, sim_input_max: 0.6, description: "Hold"}
      ]

      pid = start_preview_session(context, gate)
      :ok = NotchMappingSession.start_mapping(pid)
      capture_notch(pid, [450, 500])

      assert %{
               status: :ready,
               direction_known: false,
               direction_detectable: false,
               direction_pending: false,
               direction_overridable: false,
               direction_source: :auto,
               inverted: false
             } = NotchMappingSession.get_public_state(pid).preview

      assert {:error, :not_overridable} =
               NotchMappingSession.set_direction_override(pid, :reversed)

      NotchMappingSession.cancel(pid)
    end

    test "overridable is decided by the lever's notches, not the captures", context do
      no_sim = %{type: :linear, min_value: 0.0, max_value: 1.0, description: "Plain"}
      gate_no_sim = %{type: :gate, value: 0.0, description: "Off"}
      [linear] = @single_notch
      [braking, neutral, _power] = @override_notches

      cases = [
        {[linear], true},
        {[gate_no_sim, linear], true},
        {[linear, no_sim], true},
        {[no_sim], false},
        {[gate_no_sim, no_sim], false},
        {[neutral], false},
        {[braking, neutral], false}
      ]

      for {notches, expected} <- cases do
        pid = start_preview_session(context, notches)

        assert NotchMappingSession.get_public_state(pid).preview.direction_overridable ==
                 expected,
               inspect(Enum.map(notches, & &1.description))

        stop_session(pid)
      end
    end

    test "survives go_to_notch and re-capture", context do
      pid = start_preview_session(context, @single_notch)
      :ok = NotchMappingSession.start_mapping(pid)
      capture_notch(pid, [100, 500, 900])
      :ok = NotchMappingSession.set_direction_override(pid, :reversed)

      :ok = NotchMappingSession.go_to_notch(pid, 0)
      capture_notch(pid, [100, 500, 900])

      state = NotchMappingSession.get_public_state(pid)
      assert state.direction_override == true
      assert %{direction_source: :manual, inverted: true} = state.preview

      NotchMappingSession.cancel(pid)
    end

    test "resetting to auto restores the default", context do
      pid = start_preview_session(context, @single_notch)
      :ok = NotchMappingSession.start_mapping(pid)
      capture_notch(pid, [100, 500, 900])

      auto = NotchMappingSession.get_public_state(pid).preview
      :ok = NotchMappingSession.set_direction_override(pid, :reversed)
      assert NotchMappingSession.get_public_state(pid).preview.inverted
      :ok = NotchMappingSession.set_direction_override(pid, :auto)

      state = NotchMappingSession.get_public_state(pid)
      assert state.direction_override == nil
      assert state.preview == auto

      assert %{
               direction_source: :auto,
               direction_known: false,
               direction_overridable: true,
               inverted: false
             } = state.preview

      NotchMappingSession.cancel(pid)
    end

    test "single-notch lever can be set reversed and saves inverted", context do
      pid = start_preview_session(context, @single_notch)
      Sandbox.allow(Trenino.Repo, self(), pid)
      :ok = NotchMappingSession.start_mapping(pid)
      capture_notch(pid, [100, 500, 900])

      before = NotchMappingSession.get_public_state(pid).preview

      assert %{
               status: :ready,
               direction_known: false,
               direction_detectable: false,
               direction_overridable: true,
               direction_source: :auto,
               inverted: false
             } = before

      :ok = NotchMappingSession.set_direction_override(pid, :reversed)
      preview = NotchMappingSession.get_public_state(pid).preview

      assert %{
               direction_known: true,
               direction_detectable: false,
               direction_source: :manual,
               detected_inverted: false,
               inverted: true
             } = preview

      assert before.low_end.sim_input == 0.0
      assert before.high_end.sim_input == 1.0
      assert preview.low_end.sim_input == before.high_end.sim_input
      assert preview.high_end.sim_input == before.low_end.sim_input

      assert :ok = NotchMappingSession.save_mapping(pid)
      {:ok, saved} = Train.get_lever_config(context.element.id)

      assert saved.inverted == true
      assert {:ok, preview.low_end.sim_input} == LeverMapper.map_input(saved, 0.0)
      assert {:ok, preview.high_end.sim_input} == LeverMapper.map_input(saved, 1.0)
    end
  end

  describe "preview cache" do
    setup [:create_fixtures]

    @cache_notches [
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

    @cache_linear [
      %{
        type: :linear,
        min_value: 0.0,
        max_value: 1.0,
        sim_input_min: 0.0,
        sim_input_max: 1.0,
        description: "Throttle"
      }
    ]

    # Same final captures and override reached by different paths must give
    # identical previews: the cached one (history-dependent refreshes) and a
    # direct one.
    defp preview_after(context, notches, steps) do
      pid = start_preview_session(context, notches)
      :ok = NotchMappingSession.start_mapping(pid)

      Enum.each(steps, fn
        {:capture, raw} -> capture_notch(pid, raw)
        {:go_to, idx} -> :ok = NotchMappingSession.go_to_notch(pid, idx)
        {:override, direction} -> :ok = NotchMappingSession.set_direction_override(pid, direction)
      end)

      preview = NotchMappingSession.get_public_state(pid).preview
      stop_session(pid)
      preview
    end

    test "recapture via go_to_notch matches capturing the final values directly", context do
      recaptured =
        preview_after(context, @cache_notches, [
          {:capture, [100, 200, 300, 450]},
          {:capture, [460, 500, 540]},
          {:capture, [550, 700, 900]},
          {:go_to, 1},
          {:capture, [520, 480, 500]}
        ])

      direct =
        preview_after(context, @cache_notches, [
          {:capture, [100, 200, 300, 450]},
          {:go_to, 2},
          {:capture, [550, 700, 900]},
          {:capture, [520, 480, 500]}
        ])

      assert recaptured == direct
      assert %{status: :ready, direction_detectable: true} = recaptured
      assert Enum.find(recaptured.hardware_ranges, &(&1.notch_index == 1)).min_pct == 47.5
      assert recaptured.live != nil
    end

    test "override before capture matches override after capture", context do
      before =
        preview_after(context, @cache_linear, [
          {:override, :reversed},
          {:capture, [100, 500, 900]}
        ])

      after_capture =
        preview_after(context, @cache_linear, [
          {:capture, [100, 500, 900]},
          {:override, :reversed}
        ])

      assert before == after_capture
      assert %{direction_source: :manual, inverted: true, live: %{}} = before
    end

    test "override then auto matches never overriding", context do
      reset =
        preview_after(context, @cache_linear, [
          {:capture, [100, 500, 900]},
          {:override, :reversed},
          {:override, :auto}
        ])

      never = preview_after(context, @cache_linear, [{:capture, [100, 500, 900]}])

      assert reset == never
      assert %{direction_source: :auto, inverted: false} = reset
    end

    test "sample updates and reset_samples change only live", context do
      pid = start_preview_session(context, @cache_notches)
      :ok = NotchMappingSession.start_mapping(pid)
      capture_notch(pid, [100, 200, 300, 450])
      capture_notch(pid, [460, 500, 540])

      cache = NotchMappingSession.get_state(pid).preview_cache
      first = NotchMappingSession.get_public_state(pid).preview

      :ok = NotchMappingSession.start_capturing(pid)
      send(pid, {:input_value_updated, "/dev/test", 5, 300})
      second = NotchMappingSession.get_public_state(pid).preview

      assert Map.delete(second, :live) == Map.delete(first, :live)
      assert %{notch_index: 0, hardware_pct: 25.0} = second.live
      assert second.live != first.live

      :ok = NotchMappingSession.reset_samples(pid)
      send(pid, {:input_value_updated, "/dev/test", 5, 500})
      third = NotchMappingSession.get_public_state(pid).preview

      assert Map.delete(third, :live) == Map.delete(first, :live)
      assert %{notch_index: 1, type: :gate} = third.live
      assert NotchMappingSession.get_state(pid).preview_cache == cache

      NotchMappingSession.cancel(pid)
    end
  end

  describe "inversion detection parity" do
    setup [:create_fixtures]

    # The centre rule detect_inversion/3 used before delegating to
    # LeverMapper.descending?/1, kept here as the reference.
    defp legacy_inverted?(pairs) when length(pairs) < 2, do: false

    defp legacy_inverted?(pairs) do
      hw_center = fn {_notch, range} -> (range.min + range.max) / 2 end
      sim_center = fn {notch, _range} -> (notch.sim_input_min + notch.sim_input_max) / 2 end
      {first, _} = Enum.min_by(pairs, hw_center)
      {last, _} = Enum.max_by(pairs, hw_center)
      sim_center.({first, nil}) > sim_center.({last, nil})
    end

    @parity_notches [
      %{type: :gate, value: 0.0, sim_input_min: 0.0, sim_input_max: 0.1, description: "A"},
      %{type: :gate, value: 0.5, sim_input_min: 0.45, sim_input_max: 0.55, description: "B"},
      %{type: :gate, value: 1.0, sim_input_min: 0.9, sim_input_max: 1.0, description: "C"}
    ]

    # Raw sample pairs (calibration 100..900), including equal hardware centres
    @parity_cases [
      [[100, 150], [450, 550], [850, 900]],
      [[850, 900], [450, 550], [100, 150]],
      [[450, 550], [100, 150], [850, 900]],
      [[450, 550], [850, 900], [100, 150]],
      [[500, 500], [500, 500], [500, 500]],
      [[100, 900], [400, 600], [300, 700]]
    ]

    test "preview detection matches the legacy centre rule", context do
      for raw <- @parity_cases do
        pid = start_preview_session(context, @parity_notches)
        :ok = NotchMappingSession.start_mapping(pid)
        Enum.each(raw, &capture_notch(pid, &1))

        state = NotchMappingSession.get_state(pid)

        pairs =
          state.notches
          |> Enum.zip(state.captured_ranges)
          |> Enum.filter(fn {_n, r} -> r != nil end)

        preview = NotchMappingSession.get_public_state(pid).preview
        assert preview.detected_inverted == legacy_inverted?(pairs), inspect(raw)
        assert preview.inverted == preview.detected_inverted

        NotchMappingSession.cancel(pid)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, _, _, _}
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

  defp stop_session(pid) do
    ref = Process.monitor(pid)
    NotchMappingSession.cancel(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
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
