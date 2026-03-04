defmodule Trenino.Hardware.InputDetectionSessionTest do
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Hardware.InputDetectionSession

  @test_port "test_port"
  @input_values_topic "hardware:input_values"

  # Helper to broadcast a simulated hardware input event
  defp broadcast_input(port, pin, value) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "#{@input_values_topic}:#{port}",
      {:input_value_updated, port, pin, value}
    )
  end

  describe "start/2" do
    test "starts successfully with valid options" do
      assert {:ok, pid} = InputDetectionSession.start(self(), input_type: :any)
      assert is_pid(pid)
      InputDetectionSession.stop(pid)
    end

    test "stops the session when stop/1 is called" do
      {:ok, pid} = InputDetectionSession.start(self(), input_type: :any)
      assert Process.alive?(pid)
      InputDetectionSession.stop(pid)
      refute Process.alive?(pid)
    end
  end

  describe "button detection" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, button} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 50})

      {:ok, pid} = InputDetectionSession.start(self(), input_type: :button, timeout_ms: 5_000)

      on_exit(fn ->
        if is_pid(pid) and Process.alive?(pid), do: InputDetectionSession.stop(pid)
      end)

      %{device: device, button: button, pid: pid}
    end

    test "detects button press (0 to 1)", %{button: button} do
      # Establish baseline
      broadcast_input(@test_port, button.pin, 0)
      # Trigger change
      broadcast_input(@test_port, button.pin, 1)

      assert_receive {:input_detected, detection}, 1_000
      assert detection.pin == button.pin
      assert detection.input_type == :button
      assert detection.value == 1
    end

    test "detects button release (1 to 0)", %{button: button} do
      # Establish baseline
      broadcast_input(@test_port, button.pin, 1)
      # Trigger change
      broadcast_input(@test_port, button.pin, 0)

      assert_receive {:input_detected, detection}, 1_000
      assert detection.pin == button.pin
      assert detection.input_type == :button
      assert detection.value == 0
    end

    test "includes input metadata in detection", %{device: device, button: button} do
      broadcast_input(@test_port, button.pin, 0)
      broadcast_input(@test_port, button.pin, 1)

      assert_receive {:input_detected, detection}, 1_000
      assert detection.input_id == button.id
      assert detection.pin == button.pin
      assert detection.input_type == :button
      assert detection.name == button.name
      assert detection.device_id == device.id
      assert detection.device_name == device.name
    end

    test "does not trigger on same value repeated", %{button: button} do
      broadcast_input(@test_port, button.pin, 0)
      broadcast_input(@test_port, button.pin, 0)

      refute_receive {:input_detected, _}, 200
    end

    test "does not detect analog inputs when filtering for buttons", %{device: device} do
      {:ok, analog} =
        Hardware.create_input(device.id, %{pin: 10, input_type: :analog, sensitivity: 5})

      broadcast_input(@test_port, analog.pin, 0)
      broadcast_input(@test_port, analog.pin, 1023)

      refute_receive {:input_detected, _}, 200
    end
  end

  describe "analog detection" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, analog} =
        Hardware.create_input(device.id, %{pin: 10, input_type: :analog, sensitivity: 5})

      {:ok, pid} = InputDetectionSession.start(self(), input_type: :analog, timeout_ms: 5_000)

      on_exit(fn ->
        if is_pid(pid) and Process.alive?(pid), do: InputDetectionSession.stop(pid)
      end)

      %{device: device, analog: analog, pid: pid}
    end

    test "detects analog change above threshold", %{analog: analog} do
      # Establish baseline at 500
      broadcast_input(@test_port, analog.pin, 500)
      # Move by more than 50 units
      broadcast_input(@test_port, analog.pin, 600)

      assert_receive {:input_detected, detection}, 1_000
      assert detection.pin == analog.pin
      assert detection.input_type == :analog
      assert detection.value == 600
    end

    test "does not detect small analog change below threshold", %{analog: analog} do
      broadcast_input(@test_port, analog.pin, 500)
      # Change of 30 is below threshold of 50
      broadcast_input(@test_port, analog.pin, 530)

      refute_receive {:input_detected, _}, 200
    end

    test "detects analog change in negative direction", %{analog: analog} do
      broadcast_input(@test_port, analog.pin, 500)
      broadcast_input(@test_port, analog.pin, 430)

      assert_receive {:input_detected, detection}, 1_000
      assert detection.pin == analog.pin
      assert detection.value == 430
    end

    test "does not detect button inputs when filtering for analog", %{device: device} do
      {:ok, button} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 50})

      broadcast_input(@test_port, button.pin, 0)
      broadcast_input(@test_port, button.pin, 1)

      refute_receive {:input_detected, _}, 200
    end
  end

  describe "any input type detection" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, button} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 50})

      {:ok, analog} =
        Hardware.create_input(device.id, %{pin: 10, input_type: :analog, sensitivity: 5})

      {:ok, pid} = InputDetectionSession.start(self(), input_type: :any, timeout_ms: 5_000)

      on_exit(fn ->
        if is_pid(pid) and Process.alive?(pid), do: InputDetectionSession.stop(pid)
      end)

      %{device: device, button: button, analog: analog, pid: pid}
    end

    test "detects button inputs", %{button: button} do
      broadcast_input(@test_port, button.pin, 0)
      broadcast_input(@test_port, button.pin, 1)

      assert_receive {:input_detected, detection}, 1_000
      assert detection.pin == button.pin
      assert detection.input_type == :button
    end

    test "detects analog inputs", %{analog: analog} do
      broadcast_input(@test_port, analog.pin, 500)
      broadcast_input(@test_port, analog.pin, 600)

      assert_receive {:input_detected, detection}, 1_000
      assert detection.pin == analog.pin
      assert detection.input_type == :analog
    end
  end

  describe "timeout" do
    test "sends detection_timeout after configured timeout" do
      {:ok, pid} = InputDetectionSession.start(self(), input_type: :any, timeout_ms: 100)

      assert_receive {:detection_timeout}, 500
      refute Process.alive?(pid)
    end

    test "uses default timeout of 60 seconds when not specified" do
      # We can't wait 60 seconds, so just verify the session is still alive after a short wait
      {:ok, pid} = InputDetectionSession.start(self(), input_type: :any)

      refute_receive {:detection_timeout}, 100
      assert Process.alive?(pid)

      InputDetectionSession.stop(pid)
    end
  end

  describe "callback_pid monitoring" do
    test "stops when callback_pid dies" do
      callback_pid =
        spawn(fn ->
          receive do
            :die -> :ok
          end
        end)

      {:ok, session_pid} = InputDetectionSession.start(callback_pid, input_type: :any)
      assert Process.alive?(session_pid)

      send(callback_pid, :die)
      # Give the session time to notice the monitor
      Process.sleep(100)

      refute Process.alive?(session_pid)
    end
  end

  describe "unknown pin" do
    setup do
      {:ok, pid} = InputDetectionSession.start(self(), input_type: :any, timeout_ms: 5_000)

      on_exit(fn ->
        if is_pid(pid) and Process.alive?(pid), do: InputDetectionSession.stop(pid)
      end)

      %{pid: pid}
    end

    test "ignores events for pins not in any device configuration" do
      # Pin 99 is not configured in any device
      broadcast_input(@test_port, 99, 0)
      broadcast_input(@test_port, 99, 1)

      refute_receive {:input_detected, _}, 200
    end
  end
end
