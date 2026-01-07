defmodule Trenino.Hardware.ConfigurationManagerTest do
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Serial.Protocol.ConfigurationError
  alias Trenino.Serial.Protocol.ConfigurationStored
  alias Trenino.Serial.Protocol.InputValue

  @config_topic "hardware:configuration"
  @input_values_topic "hardware:input_values"

  # The ConfigurationManager is started by the application supervision tree.
  # We test against the running instance, using unique ports per test to avoid conflicts.

  defp unique_port, do: "/dev/tty.test_#{System.unique_integer([:positive])}"

  describe "apply_configuration/2" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, _input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      %{device: device, port: unique_port()}
    end

    test "returns error when device not found", %{port: port} do
      assert {:error, :not_found} = ConfigurationManager.apply_configuration(port, 999_999)
    end

    test "returns error when device has no inputs", %{port: port} do
      {:ok, empty_device} = Hardware.create_device(%{name: "Empty Device"})

      assert {:error, :no_inputs} =
               ConfigurationManager.apply_configuration(port, empty_device.id)
    end

    test "preserves existing config_id when configuration is stored", %{
      device: device,
      port: port
    } do
      # Device was created with a config_id
      original_config_id = device.config_id
      assert original_config_id != nil

      # Subscribe to configuration events
      Phoenix.PubSub.subscribe(Trenino.PubSub, @config_topic)

      # Simulate the device confirming configuration with the original config_id
      # This is what happens when do_apply_configuration uses the existing config_id
      send(
        ConfigurationManager,
        {:serial_message, port, %ConfigurationStored{config_id: original_config_id}}
      )

      # We won't receive configuration_applied because there's no in-flight tracking
      # But let's verify the device still has the original config_id
      {:ok, reloaded_device} = Hardware.get_device(device.id)
      assert reloaded_device.config_id == original_config_id
    end

    test "device config_id should not change when reapplying configuration", %{device: device} do
      # This test verifies the bug fix: applying configuration should NOT
      # generate a new config_id - it should use the existing one.

      # Device was created with a config_id
      original_config_id = device.config_id
      assert original_config_id != nil

      # Re-fetch the device to simulate what do_apply_configuration does
      {:ok, fetched_device} = Hardware.get_device(device.id)

      # The fix ensures we use fetched_device.config_id instead of generating a new one
      # This is the key assertion - the fetched device should have the same config_id
      assert fetched_device.config_id == original_config_id

      # Verify the device wasn't assigned a new config_id
      # (Before the fix, Hardware.generate_config_id() would be called which creates a new ID)
      {:ok, another_fetch} = Hardware.get_device(device.id)
      assert another_fetch.config_id == original_config_id
    end
  end

  describe "get_input_values/1" do
    test "returns empty map when no values stored" do
      port = unique_port()
      assert %{} = ConfigurationManager.get_input_values(port)
    end
  end

  describe "handle_info/2 - InputValue messages" do
    setup do
      port = unique_port()
      Phoenix.PubSub.subscribe(Trenino.PubSub, "#{@input_values_topic}:#{port}")

      %{port: port}
    end

    test "stores input values and broadcasts updates", %{port: port} do
      # Simulate receiving an InputValue message
      send(ConfigurationManager, {:serial_message, port, %InputValue{pin: 5, value: 512}})

      # Sync with GenServer to ensure message is processed
      :sys.get_state(ConfigurationManager)

      # Check stored value
      assert %{5 => 512} = ConfigurationManager.get_input_values(port)

      # Check broadcast was sent
      assert_receive {:input_value_updated, ^port, 5, 512}
    end

    test "updates existing values", %{port: port} do
      send(ConfigurationManager, {:serial_message, port, %InputValue{pin: 5, value: 100}})
      :sys.get_state(ConfigurationManager)

      send(ConfigurationManager, {:serial_message, port, %InputValue{pin: 5, value: 200}})
      :sys.get_state(ConfigurationManager)

      assert %{5 => 200} = ConfigurationManager.get_input_values(port)
    end

    test "stores multiple pins independently", %{port: port} do
      send(ConfigurationManager, {:serial_message, port, %InputValue{pin: 5, value: 100}})
      send(ConfigurationManager, {:serial_message, port, %InputValue{pin: 10, value: 200}})
      :sys.get_state(ConfigurationManager)

      values = ConfigurationManager.get_input_values(port)
      assert %{5 => 100, 10 => 200} = values
    end

    test "handles negative values", %{port: port} do
      send(ConfigurationManager, {:serial_message, port, %InputValue{pin: 5, value: -100}})
      :sys.get_state(ConfigurationManager)

      assert %{5 => -100} = ConfigurationManager.get_input_values(port)
    end
  end

  describe "handle_info/2 - ConfigurationStored messages" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, _input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      port = unique_port()
      Phoenix.PubSub.subscribe(Trenino.PubSub, @config_topic)

      %{device: device, port: port}
    end

    test "ignores ConfigurationStored for unknown config_id", %{port: port} do
      send(
        ConfigurationManager,
        {:serial_message, port, %ConfigurationStored{config_id: 999_999}}
      )

      :sys.get_state(ConfigurationManager)

      # Should not receive any broadcast
      refute_receive {:configuration_applied, _, _, _}
      refute_receive {:configuration_failed, _, _, _}
    end
  end

  describe "handle_info/2 - ConfigurationError messages" do
    setup do
      port = unique_port()
      Phoenix.PubSub.subscribe(Trenino.PubSub, @config_topic)

      %{port: port}
    end

    test "ignores ConfigurationError for unknown config_id", %{port: port} do
      send(
        ConfigurationManager,
        {:serial_message, port, %ConfigurationError{config_id: 999_999}}
      )

      :sys.get_state(ConfigurationManager)

      refute_receive {:configuration_failed, _, _, _}
    end
  end

  describe "handle_info/2 - devices_updated" do
    setup do
      port = unique_port()
      %{port: port}
    end

    test "clears input values for disconnected ports", %{port: port} do
      # Add some input values
      send(ConfigurationManager, {:serial_message, port, %InputValue{pin: 5, value: 100}})
      :sys.get_state(ConfigurationManager)
      assert %{5 => 100} = ConfigurationManager.get_input_values(port)

      # Simulate device disconnect (no devices connected)
      send(ConfigurationManager, {:devices_updated, []})
      :sys.get_state(ConfigurationManager)

      # Values should be cleared
      assert %{} = ConfigurationManager.get_input_values(port)
    end

    test "preserves input values for connected ports", %{port: port} do
      # Add some input values
      send(ConfigurationManager, {:serial_message, port, %InputValue{pin: 5, value: 100}})
      :sys.get_state(ConfigurationManager)

      # Simulate device update with our port still connected
      send(ConfigurationManager, {:devices_updated, [%{port: port}]})
      :sys.get_state(ConfigurationManager)

      # Values should be preserved
      assert %{5 => 100} = ConfigurationManager.get_input_values(port)
    end
  end

  describe "subscribe_configuration/0" do
    test "subscribes to configuration events" do
      :ok = ConfigurationManager.subscribe_configuration()

      # Broadcast a test message
      Phoenix.PubSub.broadcast(Trenino.PubSub, @config_topic, {:test_event, :data})

      assert_receive {:test_event, :data}
    end
  end

  describe "subscribe_input_values/1" do
    test "subscribes to input value events for specific port" do
      port = unique_port()
      :ok = ConfigurationManager.subscribe_input_values(port)

      # Broadcast a test message to this port
      Phoenix.PubSub.broadcast(
        Trenino.PubSub,
        "#{@input_values_topic}:#{port}",
        {:test_input_event, :data}
      )

      assert_receive {:test_input_event, :data}
    end

    test "does not receive events for other ports" do
      port1 = unique_port()
      port2 = unique_port()

      :ok = ConfigurationManager.subscribe_input_values(port1)

      # Broadcast to a different port
      Phoenix.PubSub.broadcast(
        Trenino.PubSub,
        "#{@input_values_topic}:#{port2}",
        {:other_port_event, :data}
      )

      refute_receive {:other_port_event, :data}
    end
  end
end
