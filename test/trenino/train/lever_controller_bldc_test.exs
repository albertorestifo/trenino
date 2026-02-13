defmodule Trenino.Train.LeverControllerBLDCTest do
  @moduledoc """
  Tests BLDC profile management in LeverController.

  Verifies that:
  - BLDC profiles are loaded when a train activates
  - BLDC profiles are deactivated when a train deactivates
  - Non-BLDC levers are skipped
  """
  use Trenino.DataCase, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias Trenino.Hardware
  alias Trenino.Serial.Connection, as: SerialConnection
  alias Trenino.Serial.Protocol.{DeactivateBLDCProfile, LoadBLDCProfile}
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.LeverController

  describe "BLDC profile loading" do
    setup :set_mimic_global
    setup :verify_on_exit!

    setup do
      # Copy the SerialConnection module for stubbing
      Mimic.copy(SerialConnection)

      # Start LeverController for tests
      start_supervised!(LeverController)

      # Create basic fixtures
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{
          pin: 0,
          name: "Test Input",
          input_type: :analog,
          sensitivity: 5
        })

      {:ok, train} =
        TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})

      {:ok, element} =
        TrainContext.create_element(train.id, %{
          name: "Throttle",
          type: :lever
        })

      # Create lever config with BLDC type
      {:ok, lever_config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "api/min",
          max_endpoint: "api/max",
          value_endpoint: "api/value",
          lever_type: :bldc
        })

      # Add BLDC notches
      {:ok, _notch1} =
        TrainContext.create_notch(lever_config.id, %{
          index: 0,
          type: :gate,
          value: 0.0,
          input_min: 0.0,
          input_max: 0.1,
          bldc_engagement: 100,
          bldc_hold: 80,
          bldc_exit: 50,
          bldc_spring_back: 120,
          bldc_damping: 30
        })

      {:ok, _notch2} =
        TrainContext.create_notch(lever_config.id, %{
          index: 1,
          type: :linear,
          min_value: 0.0,
          max_value: 1.0,
          input_min: 0.1,
          input_max: 0.9,
          bldc_damping: 20
        })

      {:ok, _notch3} =
        TrainContext.create_notch(lever_config.id, %{
          index: 2,
          type: :gate,
          value: 1.0,
          input_min: 0.9,
          input_max: 1.0,
          bldc_engagement: 100,
          bldc_hold: 80,
          bldc_exit: 50,
          bldc_spring_back: 120,
          bldc_damping: 30
        })

      # Create binding
      {:ok, _binding} = TrainContext.bind_input(lever_config.id, input.id)

      %{
        train: train,
        device: device,
        input: input,
        lever_config: lever_config,
        element: element
      }
    end

    test "loads BLDC profile when train activates", %{train: train} do
      # Track if send_message was called
      test_pid = self()

      # Mock serial connection
      SerialConnection
      |> stub(:connected_devices, fn ->
        [%{port: "/dev/ttyUSB0", status: :connected, device_config_id: "test_device"}]
      end)
      |> stub(:send_message, fn _port, %LoadBLDCProfile{} = message ->
        send(test_pid, {:bldc_profile_loaded, message})
        :ok
      end)

      # Simulate train activation
      send(LeverController, {:train_changed, train})

      # Wait for BLDC profile to be sent
      assert_receive {:bldc_profile_loaded, %LoadBLDCProfile{detents: detents, ranges: ranges}},
                     500

      # Verify profile structure
      assert length(detents) == 2
      assert length(ranges) == 1
    end

    test "deactivates BLDC profile when train deactivates", %{train: train} do
      test_pid = self()

      # Mock serial connection
      SerialConnection
      |> stub(:connected_devices, fn ->
        [%{port: "/dev/ttyUSB0", status: :connected, device_config_id: "test_device"}]
      end)
      |> stub(:send_message, fn _port, message ->
        case message do
          %LoadBLDCProfile{} -> send(test_pid, {:profile_loaded, message})
          %DeactivateBLDCProfile{} -> send(test_pid, {:profile_deactivated, message})
        end

        :ok
      end)

      # First activate the train
      send(LeverController, {:train_changed, train})
      assert_receive {:profile_loaded, %LoadBLDCProfile{}}, 500

      # Then deactivate
      send(LeverController, {:train_changed, nil})
      assert_receive {:profile_deactivated, %DeactivateBLDCProfile{pin: 0}}, 500
    end

    test "skips profile loading for non-BLDC levers", %{
      train: train,
      input: input
    } do
      test_pid = self()
      profile_count = :counters.new(1, [:atomics])

      # Mock serial connection - track number of profiles sent
      SerialConnection
      |> stub(:connected_devices, fn ->
        [%{port: "/dev/ttyUSB0", status: :connected, device_config_id: "test_device"}]
      end)
      |> stub(:send_message, fn _port, %LoadBLDCProfile{} = message ->
        :counters.add(profile_count, 1, 1)
        send(test_pid, {:bldc_profile_loaded, message})
        :ok
      end)

      # Create a continuous lever (non-BLDC)
      {:ok, element2} =
        TrainContext.create_element(train.id, %{
          name: "Brake",
          type: :lever
        })

      {:ok, lever_config2} =
        TrainContext.create_lever_config(element2.id, %{
          min_endpoint: "api/brake_min",
          max_endpoint: "api/brake_max",
          value_endpoint: "api/brake",
          lever_type: :continuous
        })

      # Create binding for continuous lever
      {:ok, _binding2} = TrainContext.bind_input(lever_config2.id, input.id)

      # Activate train with both BLDC and non-BLDC levers
      send(LeverController, {:train_changed, train})

      # Wait for profile loading to complete
      Process.sleep(200)

      # Should only receive one profile load (for the BLDC lever, not the continuous one)
      assert :counters.get(profile_count, 1) == 1
    end

    test "handles missing device gracefully when loading profiles", %{train: train} do
      # Mock no connected devices
      SerialConnection
      |> stub(:connected_devices, fn -> [] end)

      log =
        capture_log(fn ->
          send(LeverController, {:train_changed, train})
          Process.sleep(100)
        end)

      assert log =~ "No device connected, skipping BLDC profile loading"
    end
  end
end
