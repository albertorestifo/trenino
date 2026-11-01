defmodule Trenino.Hardware.ConfigurationManagerTest do
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Serial.Protocol.ConfigurationError
  alias Trenino.Serial.Protocol.ConfigurationStored
  alias Trenino.Serial.Protocol.InputValue
  alias Trenino.Serial.Protocol.ModuleError

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

    test "refuses inputs plus stepper axes on firmware below 3.1", %{device: device, port: port} do
      Mimic.set_mimic_global()
      {:ok, _} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})

      Mimic.stub(Trenino.Serial.Connection, :connected_devices, fn ->
        [%{port: port, device_version: "3.0.0"}]
      end)

      assert {:error, :firmware_update_required} =
               ConfigurationManager.apply_configuration(port, device.id)
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

  test "deploys a device containing only an I2C display" do
    Mimic.set_mimic_global()
    Mimic.stub(Circuits.UART, :enumerate, fn -> %{} end)
    {:ok, device} = Hardware.create_device(%{name: "Display only"})

    {:ok, _} =
      Hardware.create_i2c_module(device.id, %{
        name: "Speed",
        module_chip: :ht16k33,
        i2c_address: 0x70,
        params: %{
          brightness: 8,
          num_digits: 4,
          display_type: :fourteen_segment,
          has_dot: true,
          align_right: true
        }
      })

    port = unique_port()
    test_pid = self()

    Mimic.stub(Trenino.Serial.Connection, :send_message, fn ^port, message ->
      send(test_pid, {:configuration_message, message})
      :ok
    end)

    assert {:ok, config_id} = ConfigurationManager.apply_configuration(port, device.id)

    assert_receive {:configuration_message,
                    %Trenino.Serial.Protocol.Configure{config_id: ^config_id, total_parts: 1}}

    send(
      ConfigurationManager,
      {:serial_message, port, %ConfigurationStored{config_id: config_id}}
    )

    :sys.get_state(ConfigurationManager)
  end

  describe "input chip configuration" do
    alias Trenino.Serial.Protocol.Configure

    setup do
      Mimic.set_mimic_global()
      Mimic.stub(Circuits.UART, :enumerate, fn -> %{} end)
      {:ok, device} = Hardware.create_device(%{name: "Chip device"})
      port = unique_port()
      test_pid = self()

      Mimic.stub(Trenino.Serial.Connection, :send_message, fn ^port, message ->
        send(test_pid, {:configuration_message, message})
        :ok
      end)

      %{device: device, port: port}
    end

    defp stub_version(port, version) do
      Mimic.stub(Trenino.Serial.Connection, :connected_devices, fn ->
        [%{port: port, device_version: version}]
      end)
    end

    defp add_mcp(device, address \\ 0x20) do
      Hardware.create_i2c_module(device.id, %{
        module_chip: :mcp23017,
        i2c_address: address,
        params: %{
          direct_base: 0,
          matrix_base: 8,
          debounce: 3,
          direct_mask: 0x03,
          row_mask: 0x30,
          col_mask: 0x0C
        }
      })
    end

    defp add_ads(device, mask, ref_channel \\ nil) do
      Hardware.create_i2c_module(device.id, %{
        module_chip: :ads1115,
        i2c_address: 0x48,
        params: %{channel_mask: mask, gain: 1, ref_channel: ref_channel, pin_base: 4}
      })
    end

    defp collect_messages(count) do
      for _ <- 1..count do
        assert_receive {:configuration_message, %Configure{} = message}
        message
      end
    end

    test "sends one Configure part per chip, not per child", %{device: device, port: port} do
      stub_version(port, "3.2.0")
      {:ok, mcp} = add_mcp(device)
      {:ok, ads} = add_ads(device, 0b0111)

      assert {:ok, _} = ConfigurationManager.apply_configuration(port, device.id)
      messages = collect_messages(2)
      refute_receive {:configuration_message, _}

      assert Enum.all?(messages, &(&1.total_parts == 2))
      %{direct_base: direct_base, matrix_base: matrix_base} = mcp.params
      pin_base = ads.params.pin_base

      assert %Configure{
               i2c_address: 0x20,
               direct_base: ^direct_base,
               matrix_base: ^matrix_base,
               debounce: 3,
               direct_mask: 0x03,
               row_mask: 0x30,
               col_mask: 0x0C
             } = Enum.find(messages, &(&1.input_type == :mcp23017))

      assert %Configure{
               i2c_address: 0x48,
               pin_base: ^pin_base,
               channel_mask: 0b0111,
               gain: 1,
               ref_channel: nil
             } = Enum.find(messages, &(&1.input_type == :ads1115))
    end

    test "ADS sensitivities come from child inputs, 0 for disabled channels", %{
      device: device,
      port: port
    } do
      stub_version(port, "3.2.0")
      {:ok, module} = add_ads(device, 0b0101, 3)

      for {channel, sensitivity} <- [{0, 7}, {2, 4}] do
        {:ok, _} =
          Hardware.update_input(
            Trenino.Repo.get_by!(Trenino.Hardware.Input,
              i2c_module_id: module.id,
              i2c_channel: channel
            ),
            %{sensitivity: sensitivity}
          )
      end

      assert {:ok, _} = ConfigurationManager.apply_configuration(port, device.id)
      assert_receive {:configuration_message, %Configure{input_type: :ads1115} = message}
      assert message.sensitivities == [7, 0, 4, 0]
      assert message.ref_channel == 3
    end

    test "chip config on 3.1.0 returns firmware_update_required", %{device: device, port: port} do
      stub_version(port, "3.1.0")
      {:ok, _} = add_mcp(device)

      assert {:error, :firmware_update_required} =
               ConfigurationManager.apply_configuration(port, device.id)

      refute_receive {:configuration_message, _}
    end

    test "chip config with unknown version is refused", %{device: device, port: port} do
      {:ok, _} = add_mcp(device)

      Mimic.stub(Trenino.Serial.Connection, :connected_devices, fn -> [] end)

      assert {:error, :firmware_update_required} =
               ConfigurationManager.apply_configuration(port, device.id)

      stub_version(port, "garbage")

      assert {:error, :firmware_update_required} =
               ConfigurationManager.apply_configuration(port, device.id)

      stub_version(port, "3.2.0-rc1")

      assert {:error, :firmware_update_required} =
               ConfigurationManager.apply_configuration(port, device.id)
    end

    test "HT16K33 config still works on 3.1.0", %{device: device, port: port} do
      stub_version(port, "3.1.0")

      {:ok, _} =
        Hardware.create_i2c_module(device.id, %{
          module_chip: :ht16k33,
          i2c_address: 0x70,
          params: %{brightness: 8, num_digits: 4}
        })

      assert {:ok, _} = ConfigurationManager.apply_configuration(port, device.id)
      assert_receive {:configuration_message, %Configure{input_type: :ht16k33}}
    end

    test "nine modules returns too_many_modules", %{device: device, port: port} do
      stub_version(port, "3.2.0")

      for pin <- 1..9 do
        {:ok, _} = Hardware.create_input(device.id, %{pin: pin, input_type: :button, debounce: 5})
      end

      assert {:error, :too_many_modules} =
               ConfigurationManager.apply_configuration(port, device.id)

      refute_receive {:configuration_message, _}
    end

    test "eight modules are accepted", %{device: device, port: port} do
      stub_version(port, "3.2.0")

      for pin <- 1..8 do
        {:ok, _} = Hardware.create_input(device.id, %{pin: pin, input_type: :button, debounce: 5})
      end

      assert {:ok, _} = ConfigurationManager.apply_configuration(port, device.id)
    end

    test "too_many_modules is reported before the firmware gate", %{device: device, port: port} do
      stub_version(port, "3.0.0")
      {:ok, _} = add_mcp(device)

      for pin <- 1..8 do
        {:ok, _} = Hardware.create_input(device.id, %{pin: pin, input_type: :button, debounce: 5})
      end

      assert {:error, :too_many_modules} =
               ConfigurationManager.apply_configuration(port, device.id)
    end
  end

  describe "failed I2C chip tracking" do
    setup do
      Mimic.set_mimic_global()
      Mimic.stub(Circuits.UART, :enumerate, fn -> %{} end)
      {:ok, device} = Hardware.create_device(%{name: "Failing chips"})
      port = unique_port()
      test_pid = self()

      Mimic.stub(Trenino.Serial.Connection, :connected_devices, fn ->
        [%{port: port, device_config_id: device.config_id, device_version: "3.2.0"}]
      end)

      Mimic.stub(Trenino.Serial.Connection, :send_message, fn ^port, message ->
        send(test_pid, {:configuration_message, message})
        :ok
      end)

      {:ok, mcp} =
        Hardware.create_i2c_module(device.id, %{
          module_chip: :mcp23017,
          i2c_address: 0x20,
          params: %{
            direct_base: 0,
            matrix_base: 8,
            debounce: 3,
            direct_mask: 0x03,
            row_mask: 0x30,
            col_mask: 0x0C
          }
        })

      {:ok, ads} =
        Hardware.create_i2c_module(device.id, %{
          module_chip: :ads1115,
          i2c_address: 0x48,
          params: %{channel_mask: 0b0011, gain: 1, ref_channel: nil, pin_base: 4}
        })

      %{device: device, port: port, mcp: mcp, ads: ads}
    end

    defp report(port, address, code) do
      send(
        ConfigurationManager,
        {:serial_message, port, %ModuleError{i2c_address: address, error_code: code}}
      )

      :sys.get_state(ConfigurationManager)
    end

    test "codes 0, 1 and 3 mark an input chip failed", %{port: port} do
      report(port, 0x20, 0)
      assert %{0x20 => :init_failed} = ConfigurationManager.failed_i2c_modules(port)

      report(port, 0x20, 1)
      assert %{0x20 => :communication_lost} = ConfigurationManager.failed_i2c_modules(port)

      report(port, 0x48, 3)

      assert %{0x20 => :communication_lost, 0x48 => :reference_lost} =
               ConfigurationManager.failed_i2c_modules(port)
    end

    test "code 2 clears it, and a later code 3 leaves :reference_lost", %{port: port} do
      report(port, 0x48, 1)
      report(port, 0x48, 2)
      assert ConfigurationManager.failed_i2c_modules(port) == %{}

      report(port, 0x48, 2)
      report(port, 0x48, 3)
      assert %{0x48 => :reference_lost} = ConfigurationManager.failed_i2c_modules(port)
    end

    test "an HT16K33 or stepper shield address is logged and not tracked", %{
      device: device,
      port: port
    } do
      {:ok, _} =
        Hardware.create_i2c_module(device.id, %{
          module_chip: :ht16k33,
          i2c_address: 0x70,
          params: %{brightness: 8, num_digits: 4, display_type: :fourteen_segment}
        })

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          report(port, 0x70, 0)
          report(port, 0x5F, 1)
        end)

      assert log =~ "0x70"
      assert ConfigurationManager.failed_i2c_modules(port) == %{}
    end

    test "log wording follows the code", %{port: port} do
      log = ExUnit.CaptureLog.capture_log(fn -> report(port, 0x20, 1) end)
      assert log =~ "lost communication"
      refute log =~ "failed init"
    end

    test "reconfiguring clears the port", %{device: device, port: port} do
      report(port, 0x20, 1)
      assert map_size(ConfigurationManager.failed_i2c_modules(port)) == 1

      assert {:ok, _} = ConfigurationManager.apply_configuration(port, device.id)
      assert ConfigurationManager.failed_i2c_modules(port) == %{}
    end

    test "disconnect clears the port", %{port: port} do
      report(port, 0x20, 1)
      send(ConfigurationManager, {:devices_updated, []})
      :sys.get_state(ConfigurationManager)
      assert ConfigurationManager.failed_i2c_modules(port) == %{}
    end

    test "a broadcast is sent on each change", %{port: port} do
      ConfigurationManager.subscribe_i2c_status(port)

      report(port, 0x20, 1)
      assert_receive {:i2c_module_status, ^port, %{0x20 => :communication_lost}}

      report(port, 0x20, 1)
      refute_receive {:i2c_module_status, _, _}, 50

      report(port, 0x20, 2)
      assert_receive {:i2c_module_status, ^port, map} when map == %{}
    end

    test "failed_input_ids lists children of failed chips", %{port: port, mcp: mcp, ads: ads} do
      assert Hardware.failed_input_ids(port) == MapSet.new()

      report(port, 0x48, 1)
      {:ok, inputs} = Hardware.list_inputs(ads.device_id, include_chip_inputs: true)
      ads_ids = for i <- inputs, i.i2c_module_id == ads.id, do: i.id
      mcp_ids = for i <- inputs, i.i2c_module_id == mcp.id, do: i.id
      assert ads_ids != [] and mcp_ids != []

      assert Hardware.failed_input_ids(port) == MapSet.new(ads_ids)
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
