defmodule Trenino.Train.DisplayControllerTest do
  use Trenino.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Hardware.Device
  alias Trenino.Hardware.HT16K33.Params
  alias Trenino.Hardware.I2cModule
  alias Trenino.Serial.Connection
  alias Trenino.Serial.Protocol.{SetModuleBrightness, WriteSegments}
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train.DisplayBinding
  alias Trenino.Train.DisplayController
  alias Trenino.Train.DisplayController.State

  setup :set_mimic_global

  setup do
    Mimic.stub(Circuits.UART, :enumerate, fn -> %{} end)
    client = %Client{base_url: "http://localhost:31270", api_key: "test"}

    Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
      %ConnectionState{status: :connected, client: client}
    end)

    Mimic.stub(Client, :get_subscription, fn ^client, 3000 ->
      {:ok, %{"Entries" => [%{"NodeValid" => true, "Values" => %{"Speed" => 42.5}}]}}
    end)

    Mimic.stub(Connection, :connected_devices, fn ->
      [%{port: "display-port", device_config_id: 123}]
    end)

    Mimic.stub(Connection, :send_message, fn _, _ -> :ok end)

    binding = %DisplayBinding{
      id: 1,
      format_string: "{value:.1f}",
      i2c_module: %I2cModule{
        i2c_address: 0x70,
        module_chip: :ht16k33,
        params: %Params{brightness: 7},
        device: %Device{config_id: 123}
      }
    }

    state = %State{bindings: %{1 => %{binding: binding, subscription_id: 3000, last_text: nil}}}
    %{state: state}
  end

  test "does not cache a failed write and retries the unchanged value on the next poll", %{
    state: state
  } do
    Mimic.stub(Connection, :send_message, fn _, _ -> {:error, :disconnected} end)
    state = poll(state)
    assert state.bindings[1].last_text == nil
    test_pid = self()

    Mimic.stub(Connection, :send_message, fn "display-port", message ->
      send(test_pid, {:sent, message})
      :ok
    end)

    state = poll(state)
    assert state.bindings[1].last_text == "42.5"
    assert_receive {:sent, %WriteSegments{i2c_address: 0x70}}
  end

  test "does not cache values without a connected port", %{state: state} do
    Mimic.stub(Connection, :connected_devices, fn -> [] end)
    state = poll(state)
    assert state.bindings[1].last_text == nil

    Mimic.stub(Connection, :connected_devices, fn ->
      [%{port: "display-port", device_config_id: 123}]
    end)

    assert poll(state).bindings[1].last_text == "42.5"
  end

  test "replays stable text and brightness after hardware reconnect", %{state: state} do
    state = poll(state)
    test_pid = self()

    Mimic.stub(Connection, :send_message, fn "display-port", message ->
      send(test_pid, {:sent, message})
      :ok
    end)

    {:noreply, state} = DisplayController.handle_info({:devices_updated, []}, state)

    {:noreply, state} =
      DisplayController.handle_info(
        {:devices_updated, [%{port: "display-port", device_config_id: 123}]},
        state
      )

    state = poll(state)
    assert state.bindings[1].last_text == "42.5"
    assert_receive {:sent, %SetModuleBrightness{brightness: 7, i2c_address: 0x70}}
    assert_receive {:sent, %WriteSegments{i2c_address: 0x70}}
    _state = poll(state)
    refute_receive {:sent, _}
  end

  test "failed brightness delivery does not mark the display delivered", %{state: state} do
    Mimic.stub(Connection, :send_message, fn
      _, %SetModuleBrightness{} -> {:error, :disconnected}
      _, %WriteSegments{} -> :ok
    end)

    assert poll(state).bindings[1].last_text == nil
  end

  test "subscribes to a profile loaded while the simulator was disconnected" do
    {:ok, train} =
      Trenino.Train.create_train(%{
        name: "Reconnect",
        identifiers: [%{identifier: "display_reconnect"}]
      })

    {:ok, device} = Trenino.Hardware.create_device(%{name: "Reconnect display"})

    {:ok, mod} =
      Trenino.Hardware.create_i2c_module(device.id, %{
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

    {:ok, _} =
      Trenino.Train.create_display_binding(train.id, %{
        i2c_module_id: mod.id,
        endpoint: "Speed",
        format_string: "{value}"
      })

    Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
      %ConnectionState{status: :disconnected}
    end)

    controller = start_supervised!(DisplayController)
    Sandbox.allow(Trenino.Repo, self(), controller)
    send(controller, {:train_changed, train})
    assert :sys.get_state(controller).bindings == %{}
    client = %Client{base_url: "http://localhost:31270", api_key: "test"}
    connected = %ConnectionState{status: :connected, client: client}
    Mimic.stub(Trenino.Simulator.Connection, :get_status, fn -> connected end)
    Mimic.stub(Client, :subscribe, fn ^client, "Speed", 3000 -> {:ok, %{}} end)

    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "simulator:connection",
      {:simulator_status_changed, connected}
    )

    assert map_size(:sys.get_state(controller).bindings) == 1
  end

  test "configuration replay reloads persisted address, encoding, brightness and minimum" do
    {state, device, mod, binding} = persisted_display()
    state = poll(state)

    {:ok, _} =
      Trenino.Hardware.update_i2c_module(mod, %{
        i2c_address: 0x71,
        params: %{
          brightness: 12,
          num_digits: 8,
          display_type: :seven_segment,
          align_right: false,
          has_dot: true,
          min_value: 50.0
        }
      })

    test_pid = self()

    Mimic.stub(Connection, :send_message, fn "display-port", message ->
      send(test_pid, {:sent, message})
      :ok
    end)

    {:noreply, state} =
      DisplayController.handle_info(
        {:configuration_applied, "display-port", device, device.config_id},
        state
      )

    state = poll(state)
    assert state.bindings[binding.id].last_text == "50.0"
    assert_receive {:sent, %SetModuleBrightness{i2c_address: 0x71, brightness: 12}}

    assert_receive {:sent,
                    %WriteSegments{i2c_address: 0x71, data: <<0x6D, 0xBF, 0x3F, 0, 0, 0, 0, 0>>}}

    refute_receive {:sent, %SetModuleBrightness{i2c_address: 0x70}}
  end

  test "configuration replay drops removed modules and stops their poll timer" do
    {state, device, mod, _binding} = persisted_display()
    {:ok, _} = Trenino.Hardware.delete_i2c_module(mod)

    {:noreply, refreshed} =
      DisplayController.handle_info(
        {:configuration_applied, "display-port", device, device.config_id},
        state
      )

    if refreshed.poll_timer, do: Process.cancel_timer(refreshed.poll_timer)
    assert refreshed.bindings == %{}
    assert refreshed.subscriptions == %{}
    assert refreshed.poll_timer == nil
    assert Process.read_timer(state.poll_timer) == false
  end

  test "a persisted nil minimum renders negative simulator values" do
    {state, _device, mod, binding} = persisted_display()
    {:ok, _} = Trenino.Hardware.update_i2c_module(mod, %{params: %{min_value: nil}})

    Mimic.stub(Client, :get_subscription, fn _, 3000 ->
      {:ok, %{"Entries" => [%{"NodeValid" => true, "Values" => %{"Speed" => -12.5}}]}}
    end)

    {:noreply, state} = DisplayController.handle_cast(:reload_bindings, state)
    assert poll(state).bindings[binding.id].last_text == "-12.5"
  end

  defp persisted_display do
    {:ok, train} =
      Trenino.Train.create_train(%{name: "Settings", identifiers: [%{identifier: "settings"}]})

    {:ok, device} = Trenino.Hardware.create_device(%{name: "Settings display"})

    {:ok, mod} =
      Trenino.Hardware.create_i2c_module(device.id, %{
        module_chip: :ht16k33,
        i2c_address: 0x70,
        params: %{
          brightness: 7,
          num_digits: 4,
          display_type: :fourteen_segment,
          has_dot: false,
          align_right: true,
          min_value: 0.0
        }
      })

    {:ok, binding} =
      Trenino.Train.create_display_binding(train.id, %{
        i2c_module_id: mod.id,
        endpoint: "Speed",
        format_string: "{value:.1f}"
      })

    Mimic.stub(Connection, :connected_devices, fn ->
      [%{port: "display-port", device_config_id: device.config_id}]
    end)

    Mimic.stub(Client, :subscribe, fn _, "Speed", 3000 -> {:ok, %{}} end)
    Mimic.stub(Client, :unsubscribe, fn _, 3000 -> :ok end)
    {:noreply, state} = DisplayController.handle_info({:train_changed, train}, %State{})
    {state, device, mod, binding}
  end

  test "a queued poll cannot leave a second polling timer alive", %{state: state} do
    {:noreply, first} = DisplayController.handle_info(:poll_displays, state)
    {:noreply, second} = DisplayController.handle_info(:poll_displays, first)

    try do
      assert Process.read_timer(first.poll_timer) == false
    after
      Process.cancel_timer(first.poll_timer)
      Process.cancel_timer(second.poll_timer)
    end
  end

  defp poll(state) do
    {:noreply, state} = DisplayController.handle_info(:poll_displays, state)
    if state.poll_timer, do: Process.cancel_timer(state.poll_timer)
    %{state | poll_timer: nil}
  end
end
