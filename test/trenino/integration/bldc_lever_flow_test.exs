defmodule Trenino.Integration.BLDCLeverFlowTest do
  @moduledoc """
  End-to-end integration tests for complete BLDC lever flow.

  Tests the entire lifecycle:
  - Train creation with BLDC lever configuration
  - Notch creation with BLDC parameters
  - Device setup and connection
  - Train activation triggering BLDC profile loading
  - Profile structure validation
  - Train deactivation and profile cleanup
  - Switching between trains with different BLDC profiles
  """

  use Trenino.DataCase, async: false
  use Mimic

  alias Trenino.Hardware
  alias Trenino.Serial.Connection, as: SerialConnection
  alias Trenino.Serial.Protocol.{DeactivateBLDCProfile, LoadBLDCProfile}
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.LeverController

  @moduletag :integration

  describe "complete BLDC configuration and activation flow" do
    setup :set_mimic_global
    setup :verify_on_exit!

    setup do
      # Copy the SerialConnection module for stubbing
      Mimic.copy(SerialConnection)

      # Start LeverController for tests
      start_supervised!(LeverController)

      # Create device and input
      {:ok, device} = Hardware.create_device(%{name: "Test BLDC Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{
          pin: 0,
          name: "BLDC Throttle Input",
          input_type: :analog,
          sensitivity: 5
        })

      %{
        device: device,
        input: input
      }
    end

    test "end-to-end BLDC flow: create, configure, activate, verify, deactivate", %{
      input: input
    } do
      test_pid = self()

      # Step 1: Create train with BLDC lever
      {:ok, train} =
        TrainContext.create_train(%{
          name: "BLDC Test Train",
          identifier: "bldc_test_train"
        })

      {:ok, element} =
        TrainContext.create_element(train.id, %{
          name: "BLDC Throttle",
          type: :lever
        })

      {:ok, lever_config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "api/throttle/min",
          max_endpoint: "api/throttle/max",
          value_endpoint: "api/throttle/value",
          lever_type: :bldc
        })

      # Step 2: Create 3 notches (gate, linear, gate) with BLDC params
      {:ok, _notch1} =
        TrainContext.create_notch(lever_config.id, %{
          index: 0,
          type: :gate,
          value: 0.0,
          input_min: 0.0,
          input_max: 0.15,
          bldc_engagement: 110,
          bldc_hold: 85,
          bldc_exit: 55,
          bldc_spring_back: 125,
          bldc_damping: 35
        })

      {:ok, _notch2} =
        TrainContext.create_notch(lever_config.id, %{
          index: 1,
          type: :linear,
          min_value: 0.0,
          max_value: 1.0,
          input_min: 0.15,
          input_max: 0.85,
          bldc_damping: 25
        })

      {:ok, _notch3} =
        TrainContext.create_notch(lever_config.id, %{
          index: 2,
          type: :gate,
          value: 1.0,
          input_min: 0.85,
          input_max: 1.0,
          bldc_engagement: 105,
          bldc_hold: 80,
          bldc_exit: 52,
          bldc_spring_back: 118,
          bldc_damping: 32
        })

      # Step 3: Create input binding
      {:ok, _binding} = TrainContext.bind_input(lever_config.id, input.id)

      # Step 4: Setup mock device
      SerialConnection
      |> stub(:connected_devices, fn ->
        [%{port: "/dev/ttyUSB0", status: :connected, device_config_id: "bldc_device"}]
      end)
      |> stub(:send_message, fn _port, message ->
        case message do
          %LoadBLDCProfile{} -> send(test_pid, {:profile_loaded, message})
          %DeactivateBLDCProfile{} -> send(test_pid, {:profile_deactivated, message})
        end

        :ok
      end)

      # Step 5: Activate train
      send(LeverController, {:train_changed, train})

      # Step 6: Verify LoadBLDCProfile sent with correct structure
      assert_receive {:profile_loaded, profile}, 500
      assert %LoadBLDCProfile{} = profile
      assert profile.pin == 0

      # Verify detents (2 gate notches should create 2 detents)
      assert length(profile.detents) == 2
      [detent1, detent2] = profile.detents

      # First detent (from notch at index 0)
      assert detent1.position >= 0 and detent1.position <= 255
      assert detent1.engagement == 110
      assert detent1.hold == 85
      assert detent1.exit == 55
      assert detent1.spring_back == 125

      # Second detent (from notch at index 2)
      assert detent2.position >= 0 and detent2.position <= 255
      assert detent2.engagement == 105
      assert detent2.hold == 80
      assert detent2.exit == 52
      assert detent2.spring_back == 118

      # Verify ranges (1 linear notch should create 1 range)
      assert length(profile.ranges) == 1
      [range1] = profile.ranges

      # Ranges use detent indices, not positions
      assert range1.start_detent >= 0
      assert range1.end_detent >= 0
      assert range1.damping == 25

      # Step 7: Deactivate train
      send(LeverController, {:train_changed, nil})

      # Step 8: Verify DeactivateBLDCProfile sent
      assert_receive {:profile_deactivated, deactivate_msg}, 500
      assert %DeactivateBLDCProfile{pin: 0} = deactivate_msg
    end

    test "validates BLDC profile structure with realistic parameters", %{input: input} do
      test_pid = self()

      # Create a realistic train configuration
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Realistic BLDC Train",
          identifier: "realistic_bldc"
        })

      {:ok, element} =
        TrainContext.create_element(train.id, %{
          name: "Power Handle",
          type: :lever
        })

      {:ok, lever_config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "api/power/min",
          max_endpoint: "api/power/max",
          value_endpoint: "api/power/value",
          lever_type: :bldc
        })

      # Create notches with varying parameters
      # Pattern: gate - linear - gate - linear - gate (realistic power handle)
      {:ok, _notch1} =
        TrainContext.create_notch(lever_config.id, %{
          index: 0,
          type: :gate,
          value: 0.0,
          input_min: 0.0,
          input_max: 0.1,
          bldc_engagement: 95,
          bldc_hold: 75,
          bldc_exit: 45,
          bldc_spring_back: 110,
          bldc_damping: 28
        })

      {:ok, _notch2} =
        TrainContext.create_notch(lever_config.id, %{
          index: 1,
          type: :linear,
          min_value: 0.0,
          max_value: 0.5,
          input_min: 0.1,
          input_max: 0.5,
          bldc_damping: 18
        })

      {:ok, _notch3} =
        TrainContext.create_notch(lever_config.id, %{
          index: 2,
          type: :gate,
          value: 0.5,
          input_min: 0.5,
          input_max: 0.6,
          bldc_engagement: 120,
          bldc_hold: 90,
          bldc_exit: 60,
          bldc_spring_back: 130,
          bldc_damping: 40
        })

      {:ok, _notch4} =
        TrainContext.create_notch(lever_config.id, %{
          index: 3,
          type: :linear,
          min_value: 0.5,
          max_value: 1.0,
          input_min: 0.6,
          input_max: 0.9,
          bldc_damping: 22
        })

      {:ok, _notch5} =
        TrainContext.create_notch(lever_config.id, %{
          index: 4,
          type: :gate,
          value: 1.0,
          input_min: 0.9,
          input_max: 1.0,
          bldc_engagement: 100,
          bldc_hold: 82,
          bldc_exit: 48,
          bldc_spring_back: 115,
          bldc_damping: 30
        })

      {:ok, _binding} = TrainContext.bind_input(lever_config.id, input.id)

      SerialConnection
      |> stub(:connected_devices, fn ->
        [%{port: "/dev/ttyUSB0", status: :connected}]
      end)
      |> stub(:send_message, fn _port, %LoadBLDCProfile{} = message ->
        send(test_pid, {:profile_loaded, message})
        :ok
      end)

      send(LeverController, {:train_changed, train})

      assert_receive {:profile_loaded, profile}, 500

      # Should have 3 detents (3 gate notches)
      assert length(profile.detents) == 3

      # Should have 2 ranges (2 linear notches, each between two gates)
      assert length(profile.ranges) == 2

      # Verify detent parameters are within valid ranges (0-255)
      Enum.each(profile.detents, fn detent ->
        assert detent.position >= 0 and detent.position <= 255
        assert detent.engagement >= 0 and detent.engagement <= 255
        assert detent.hold >= 0 and detent.hold <= 255
        assert detent.exit >= 0 and detent.exit <= 255
        assert detent.spring_back >= 0 and detent.spring_back <= 255
      end)

      # Verify range parameters - ranges use detent indices
      # Note: ranges connect linear notches to adjacent gate detents
      Enum.each(profile.ranges, fn range ->
        assert is_integer(range.start_detent), "start_detent should be an integer"
        assert is_integer(range.end_detent), "end_detent should be an integer"
        assert range.start_detent >= 0, "start_detent should be >= 0"
        assert range.end_detent >= 0, "end_detent should be >= 0"
        assert range.damping >= 0 and range.damping <= 255
      end)
    end
  end

  describe "switching between trains with different BLDC profiles" do
    setup :set_mimic_global
    setup :verify_on_exit!

    setup do
      Mimic.copy(SerialConnection)
      start_supervised!(LeverController)

      # Create shared device and inputs
      {:ok, device} = Hardware.create_device(%{name: "Shared Device"})

      {:ok, input1} =
        Hardware.create_input(device.id, %{
          pin: 0,
          name: "Input 1",
          input_type: :analog,
          sensitivity: 5
        })

      {:ok, input2} =
        Hardware.create_input(device.id, %{
          pin: 1,
          name: "Input 2",
          input_type: :analog,
          sensitivity: 5
        })

      %{device: device, input1: input1, input2: input2}
    end

    test "switches between trains with different BLDC configurations", %{
      input1: input1,
      input2: input2
    } do
      test_pid = self()

      # Create first train with 2-notch BLDC configuration
      {:ok, train1} =
        TrainContext.create_train(%{
          name: "Train 1 - Simple BLDC",
          identifier: "train_1"
        })

      {:ok, element1} =
        TrainContext.create_element(train1.id, %{
          name: "Simple Throttle",
          type: :lever
        })

      {:ok, lever_config1} =
        TrainContext.create_lever_config(element1.id, %{
          min_endpoint: "api/t1/min",
          max_endpoint: "api/t1/max",
          value_endpoint: "api/t1/value",
          lever_type: :bldc
        })

      {:ok, _notch1} =
        TrainContext.create_notch(lever_config1.id, %{
          index: 0,
          type: :gate,
          value: 0.0,
          input_min: 0.0,
          input_max: 0.5,
          bldc_engagement: 100,
          bldc_hold: 80,
          bldc_exit: 50,
          bldc_spring_back: 120,
          bldc_damping: 30
        })

      {:ok, _notch2} =
        TrainContext.create_notch(lever_config1.id, %{
          index: 1,
          type: :gate,
          value: 1.0,
          input_min: 0.5,
          input_max: 1.0,
          bldc_engagement: 105,
          bldc_hold: 85,
          bldc_exit: 55,
          bldc_spring_back: 125,
          bldc_damping: 35
        })

      {:ok, _binding1} = TrainContext.bind_input(lever_config1.id, input1.id)

      # Create second train with 3-notch BLDC configuration (gate-linear-gate)
      {:ok, train2} =
        TrainContext.create_train(%{
          name: "Train 2 - Complex BLDC",
          identifier: "train_2"
        })

      {:ok, element2} =
        TrainContext.create_element(train2.id, %{
          name: "Complex Throttle",
          type: :lever
        })

      {:ok, lever_config2} =
        TrainContext.create_lever_config(element2.id, %{
          min_endpoint: "api/t2/min",
          max_endpoint: "api/t2/max",
          value_endpoint: "api/t2/value",
          lever_type: :bldc
        })

      {:ok, _notch1} =
        TrainContext.create_notch(lever_config2.id, %{
          index: 0,
          type: :gate,
          value: 0.0,
          input_min: 0.0,
          input_max: 0.2,
          bldc_engagement: 90,
          bldc_hold: 70,
          bldc_exit: 40,
          bldc_spring_back: 110,
          bldc_damping: 25
        })

      {:ok, _notch2} =
        TrainContext.create_notch(lever_config2.id, %{
          index: 1,
          type: :linear,
          min_value: 0.0,
          max_value: 1.0,
          input_min: 0.2,
          input_max: 0.8,
          bldc_damping: 20
        })

      {:ok, _notch3} =
        TrainContext.create_notch(lever_config2.id, %{
          index: 2,
          type: :gate,
          value: 1.0,
          input_min: 0.8,
          input_max: 1.0,
          bldc_engagement: 115,
          bldc_hold: 95,
          bldc_exit: 65,
          bldc_spring_back: 135,
          bldc_damping: 38
        })

      {:ok, _binding2} = TrainContext.bind_input(lever_config2.id, input2.id)

      # Setup mock device
      SerialConnection
      |> stub(:connected_devices, fn ->
        [%{port: "/dev/ttyUSB0", status: :connected}]
      end)
      |> stub(:send_message, fn _port, message ->
        case message do
          %LoadBLDCProfile{} = profile -> send(test_pid, {:profile_loaded, profile})
          %DeactivateBLDCProfile{} = msg -> send(test_pid, {:profile_deactivated, msg})
        end

        :ok
      end)

      # Activate train 1
      send(LeverController, {:train_changed, train1})

      # Verify profile 1 loaded (2 detents, 0 ranges)
      assert_receive {:profile_loaded, profile1}, 500
      assert [_, _] = profile1.detents
      assert profile1.ranges == []
      # Verify it has train1's specific parameters
      assert Enum.any?(profile1.detents, fn d -> d.engagement == 100 end)
      assert Enum.any?(profile1.detents, fn d -> d.engagement == 105 end)

      # Deactivate train 1
      send(LeverController, {:train_changed, nil})

      # Verify train 1 profile deactivated
      assert_receive {:profile_deactivated, %DeactivateBLDCProfile{pin: 0}}, 500

      # Switch to train 2
      send(LeverController, {:train_changed, train2})

      # Verify profile 2 loaded (2 detents, 1 range)
      assert_receive {:profile_loaded, profile2}, 500
      assert [_, _] = profile2.detents
      assert [_] = profile2.ranges
      # Verify it has train2's specific parameters
      assert Enum.any?(profile2.detents, fn d -> d.engagement == 90 end)
      assert Enum.any?(profile2.detents, fn d -> d.engagement == 115 end)
      assert hd(profile2.ranges).damping == 20

      # Deactivate train 2
      send(LeverController, {:train_changed, nil})

      # Verify train 2 profile deactivated
      assert_receive {:profile_deactivated, %DeactivateBLDCProfile{pin: 0}}, 500

      # Switch back to train 1
      send(LeverController, {:train_changed, train1})

      # Verify profile 1 loaded again
      assert_receive {:profile_loaded, profile1_again}, 500
      assert [_, _] = profile1_again.detents
      assert profile1_again.ranges == []
    end

    test "handles mixed BLDC and non-BLDC levers on same train", %{input1: input1, input2: input2} do
      test_pid = self()

      # Create train with both BLDC and continuous levers
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Mixed Lever Train",
          identifier: "mixed_train"
        })

      # BLDC Throttle
      {:ok, throttle_element} =
        TrainContext.create_element(train.id, %{
          name: "BLDC Throttle",
          type: :lever
        })

      {:ok, throttle_config} =
        TrainContext.create_lever_config(throttle_element.id, %{
          min_endpoint: "api/throttle/min",
          max_endpoint: "api/throttle/max",
          value_endpoint: "api/throttle/value",
          lever_type: :bldc
        })

      {:ok, _} =
        TrainContext.create_notch(throttle_config.id, %{
          index: 0,
          type: :gate,
          value: 0.0,
          input_min: 0.0,
          input_max: 1.0,
          bldc_engagement: 100,
          bldc_hold: 80,
          bldc_exit: 50,
          bldc_spring_back: 120,
          bldc_damping: 30
        })

      {:ok, _binding1} = TrainContext.bind_input(throttle_config.id, input1.id)

      # Continuous Brake
      {:ok, brake_element} =
        TrainContext.create_element(train.id, %{
          name: "Continuous Brake",
          type: :lever
        })

      {:ok, brake_config} =
        TrainContext.create_lever_config(brake_element.id, %{
          min_endpoint: "api/brake/min",
          max_endpoint: "api/brake/max",
          value_endpoint: "api/brake/value",
          lever_type: :continuous
        })

      {:ok, _binding2} = TrainContext.bind_input(brake_config.id, input2.id)

      # Setup mock device - only BLDC profile should be sent, not continuous
      profile_count = :counters.new(1, [:atomics])

      SerialConnection
      |> stub(:connected_devices, fn ->
        [%{port: "/dev/ttyUSB0", status: :connected}]
      end)
      |> stub(:send_message, fn _port, %LoadBLDCProfile{} = message ->
        :counters.add(profile_count, 1, 1)
        send(test_pid, {:profile_loaded, message})
        :ok
      end)

      # Activate train
      send(LeverController, {:train_changed, train})

      # Should receive exactly one BLDC profile (for throttle, not brake)
      assert_receive {:profile_loaded, profile}, 500
      assert length(profile.detents) == 1

      # Give time for any additional messages
      Process.sleep(100)

      # Verify only one profile was sent
      assert :counters.get(profile_count, 1) == 1
    end
  end
end
