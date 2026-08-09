defmodule Trenino.VirtualJoystick.ManagerTest do
  use ExUnit.Case, async: false

  alias Trenino.Hardware.{Device, Input}
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.VirtualJoystick.{Configuration, Manager, Mapping}

  defmodule FakePlatform do
    def windows?, do: Agent.get(agent(), & &1.windows?)
    defp agent, do: Application.fetch_env!(:trenino, :virtual_joystick_manager_test_agent)
  end

  defmodule FakeContext do
    def get_configuration,
      do: Agent.get(agent(), &%Configuration{id: 1, enabled: &1.requested?, device_index: 1})

    def list_mappings, do: Agent.get(agent(), & &1.mappings)

    def confirm_enabled(enabled?) do
      Agent.update(agent(), fn state ->
        send(state.test, {:persisted, enabled?})
        %{state | requested?: enabled?}
      end)

      {:ok, %Configuration{id: 1, enabled: enabled?, device_index: 1}}
    end

    defp agent, do: Application.fetch_env!(:trenino, :virtual_joystick_manager_test_agent)
  end

  defmodule FakeConfigurator do
    def status, do: Agent.get(agent(), & &1.device_status)

    def create do
      Agent.get_and_update(agent(), fn state ->
        send(state.test, :create_called)
        {state.create_result, maybe_apply_status(state, state.create_result, :compatible)}
      end)
    end

    def delete do
      Agent.get_and_update(agent(), fn state ->
        send(state.test, :delete_called)
        {state.delete_result, maybe_apply_status(state, state.delete_result, :device_missing)}
      end)
    end

    defp maybe_apply_status(state, :ok, status), do: %{state | device_status: status}
    defp maybe_apply_status(state, _result, _status), do: state
    defp agent, do: Application.fetch_env!(:trenino, :virtual_joystick_manager_test_agent)
  end

  defmodule FakeBridge do
    def start_link(opts) do
      owner = Keyword.fetch!(opts, :owner)

      Agent.get_and_update(agent(), fn state ->
        send(state.test, {:bridge_started, owner})
        start_result(state, owner)
      end)
    end

    defp start_result(%{bridge_results: [{:error, reason} | rest]} = state, _owner),
      do: {{:error, reason}, %{state | bridge_results: rest}}

    defp start_result(%{bridge_results: [result | rest]} = state, owner)
         when result in [:ready, :silent] do
      pid = spawn_link(fn -> loop(state.test) end)
      if result == :ready, do: send_ready(owner)
      {{:ok, pid}, %{state | bridge_results: rest}}
    end

    defp start_result(%{bridge_results: []} = state, owner) do
      pid = spawn_link(fn -> loop(state.test) end)
      send_ready(owner)
      {{:ok, pid}, state}
    end

    defp send_ready(owner) do
      send(
        owner,
        {:virtual_joystick_bridge, {:ready, %{device: 1, axis_min: 0, axis_max: 32_767}}}
      )
    end

    def set_axis(pid, axis, value), do: call(pid, {:axis, axis, value})
    def set_button(pid, button, pressed), do: call(pid, {:button, button, pressed})
    def reset(pid), do: call(pid, :reset)
    def shutdown(pid), do: call(pid, :shutdown)

    defp call(pid, command) do
      send(pid, {:command, self(), command})

      receive do
        {:bridge_reply, ^pid, reply} -> reply
      after
        500 -> {:error, :timeout}
      end
    end

    defp loop(test) do
      receive do
        {:command, caller, command} ->
          send(test, {:bridge_command, self(), command})
          send(caller, {:bridge_reply, self(), :ok})
          if command == :shutdown, do: :ok, else: loop(test)
      end
    end

    defp agent, do: Application.fetch_env!(:trenino, :virtual_joystick_manager_test_agent)
  end

  defmodule FakeSerial do
    def subscribe, do: :ok
    def list_devices, do: Agent.get(agent(), & &1.devices)
    defp agent, do: Application.fetch_env!(:trenino, :virtual_joystick_manager_test_agent)
  end

  defmodule FakeInputs do
    def subscribe_input_values(port) do
      Agent.get(agent(), fn state -> send(state.test, {:subscribed, port}) end)
      :ok
    end

    def get_input_values(port), do: Agent.get(agent(), &Map.get(&1.raw_values, port, %{}))
    defp agent, do: Application.fetch_env!(:trenino, :virtual_joystick_manager_test_agent)
  end

  setup do
    test = self()

    {:ok, agent} =
      Agent.start_link(fn ->
        %{
          test: test,
          windows?: true,
          requested?: false,
          device_status: :device_missing,
          create_result: :ok,
          delete_result: :ok,
          bridge_results: [:ready],
          mappings: [],
          devices: [],
          raw_values: %{}
        }
      end)

    Application.put_env(:trenino, :virtual_joystick_manager_test_agent, agent)

    on_exit(fn -> Application.delete_env(:trenino, :virtual_joystick_manager_test_agent) end)

    %{agent: agent}
  end

  test "startup reconciliation covers unsupported and every requested/device pair", %{
    agent: agent
  } do
    cases = [
      {false, false, :device_missing, :unsupported},
      {true, false, :device_missing, :off},
      {true, false, :compatible, :needs_cleanup},
      {true, false, :incompatible, :error},
      {true, false, :busy, :error},
      {true, true, :device_missing, :needs_setup},
      {true, true, :incompatible, :error},
      {true, true, :busy, :error},
      {true, true, :compatible, :active}
    ]

    Enum.each(cases, fn {windows?, requested?, device_status, expected} ->
      Agent.update(
        agent,
        &%{
          &1
          | windows?: windows?,
            requested?: requested?,
            device_status: device_status,
            bridge_results: [:ready]
        }
      )

      pid = start_manager()
      assert eventually(fn -> Manager.status(pid) == expected end)
      GenServer.stop(pid)
    end)
  end

  test "enable is asynchronous, rejects concurrent commands, and persists only after bridge ready",
       %{agent: agent} do
    Agent.update(agent, &%{&1 | bridge_results: [:silent]})
    pid = start_manager()

    assert :ok = Manager.enable(pid)
    assert Manager.status(pid) == :enabling
    assert Manager.disable(pid) == {:error, :transition_in_progress}
    assert_receive :create_called
    refute_receive {:persisted, true}, 30
    assert_receive {:bridge_started, ^pid}

    send(pid, {:virtual_joystick_bridge, {:ready, %{device: 1, axis_min: 0, axis_max: 32_767}}})
    assert_receive {:persisted, true}
    assert eventually(fn -> Manager.status(pid) == :active end)
  end

  test "enable cancellation leaves confirmed off state and does not persist", %{agent: agent} do
    Phoenix.PubSub.subscribe(Trenino.PubSub, "virtual_joystick")
    Agent.update(agent, &%{&1 | create_result: {:error, :uac_cancelled}})
    pid = start_manager()
    assert :ok = Manager.enable(pid)
    assert eventually(fn -> Manager.status(pid) == :off end)

    assert_receive {:virtual_joystick_status_details_changed,
                    %{status: :off, reason: :uac_cancelled}}

    assert Manager.status_details(pid) == %{status: :off, reason: :uac_cancelled}
    refute_receive {:persisted, true}
  end

  test "failure after creation offers cleanup without persisting enabled", %{agent: agent} do
    Agent.update(agent, &%{&1 | bridge_results: [{:error, :device_busy}]})
    pid = start_manager()
    assert :ok = Manager.enable(pid)
    assert eventually(fn -> Manager.status(pid) == :needs_cleanup end)
    refute_receive {:persisted, true}
  end

  test "disable resets and shuts down before deletion and persists only on confirmed removal", %{
    agent: agent
  } do
    Agent.update(agent, &%{&1 | requested?: true, device_status: :compatible})
    pid = start_manager()
    assert eventually(fn -> Manager.status(pid) == :active end)
    assert :ok = Manager.disable(pid)
    assert Manager.status(pid) == :disabling
    assert_receive {:bridge_command, bridge, :reset}
    assert_receive {:bridge_command, ^bridge, :shutdown}
    assert_receive :delete_called
    assert_receive {:persisted, false}
    assert eventually(fn -> Manager.status(pid) == :off end)
  end

  test "failed disable preserves requested enabled state", %{agent: agent} do
    Agent.update(
      agent,
      &%{
        &1
        | requested?: true,
          device_status: :compatible,
          delete_result: {:error, :uac_cancelled}
      }
    )

    Agent.update(agent, &%{&1 | bridge_results: [:ready, :ready]})
    pid = start_manager()
    assert eventually(fn -> Manager.status(pid) == :active end)
    assert_receive {:bridge_started, ^pid}
    assert :ok = Manager.disable(pid)
    assert_receive {:bridge_started, ^pid}
    assert eventually(fn -> Manager.status(pid) == :active end)
    refute_receive {:persisted, false}
  end

  test "remove leftover retries deletion and retry starts setup explicitly", %{agent: agent} do
    Agent.update(agent, &%{&1 | device_status: :compatible})
    pid = start_manager()
    assert Manager.status(pid) == :needs_cleanup
    assert :ok = Manager.remove_leftover(pid)
    assert eventually(fn -> Manager.status(pid) == :off end)
    refute_receive {:persisted, false}

    Agent.update(
      agent,
      &%{&1 | requested?: true, device_status: :device_missing, bridge_results: [:ready]}
    )

    GenServer.stop(pid)
    pid = start_manager()
    assert Manager.status(pid) == :needs_setup
    assert :ok = Manager.retry(pid)
    assert_receive {:persisted, true}
    assert eventually(fn -> Manager.status(pid) == :active end)
  end

  test "status broadcasts only on changes" do
    Phoenix.PubSub.subscribe(Trenino.PubSub, "virtual_joystick")
    pid = start_manager()
    assert :ok = Manager.reload_mappings(pid)
    refute_receive {:virtual_joystick_status_changed, _}
    assert :ok = Manager.enable(pid)
    assert_receive {:virtual_joystick_status_changed, :enabling}
    assert_receive {:virtual_joystick_status_changed, :active}
  end

  test "exposes status reasons and repair only rechecks incompatible installation state", %{
    agent: agent
  } do
    Agent.update(agent, &%{&1 | requested?: false, device_status: :driver_missing})
    pid = start_manager()
    assert Manager.status_details(pid) == %{status: :error, reason: :driver_missing}

    Agent.update(agent, &%{&1 | device_status: :compatible})
    assert :ok = Manager.repair(pid)
    assert Manager.status_details(pid) == %{status: :needs_cleanup, reason: :leftover_device}
    refute_receive {:bridge_started, ^pid}
  end

  test "loads mappings, subscribes once, uses handshake range, and activates cached raw state", %{
    agent: agent
  } do
    {axis, button} = mappings()
    devices = [%{port: "COM1", status: :connected, device_config_id: 101}]

    Agent.update(
      agent,
      &%{
        &1
        | requested?: true,
          device_status: :compatible,
          mappings: [axis, button],
          devices: devices,
          raw_values: %{"COM1" => %{5 => 100, 6 => 1}}
      }
    )

    pid = start_manager()
    assert_receive {:subscribed, "COM1"}
    refute_receive {:subscribed, "COM1"}
    assert_receive {:bridge_command, _, {:axis, :x, 32_767}}
    assert_receive {:bridge_command, _, {:button, 4, true}}

    send(pid, {:input_value_updated, "COM1", 5, 0})
    assert_receive {:bridge_command, _, {:axis, :x, 0}}
  end

  test "caches input while off and publishes it after activation", %{agent: agent} do
    {axis, _button} = mappings()
    devices = [%{port: "COM1", status: :connected, device_config_id: 101}]
    Agent.update(agent, &%{&1 | mappings: [axis], devices: devices, raw_values: %{}})
    pid = start_manager()
    send(pid, {:input_value_updated, "COM1", 5, 100})
    :sys.get_state(pid)
    assert :ok = Manager.enable(pid)
    assert_receive {:bridge_command, _, {:axis, :x, 32_767}}
  end

  test "disconnect sends safe values only for controls from the disconnected port", %{
    agent: agent
  } do
    {axis, button} = mappings()

    other = %{
      button
      | id: 3,
        button: 5,
        input: %{button.input | id: 12, pin: 7, device: %Device{id: 2, config_id: 102}}
    }

    devices = [
      %{port: "COM1", status: :connected, device_config_id: 101},
      %{port: "COM2", status: :connected, device_config_id: 102}
    ]

    Agent.update(
      agent,
      &%{
        &1
        | requested?: true,
          device_status: :compatible,
          mappings: [axis, button, other],
          devices: devices
      }
    )

    pid = start_manager()
    assert eventually(fn -> Manager.status(pid) == :active end)
    Process.sleep(5)
    drain_bridge_commands()
    Agent.update(agent, &%{&1 | devices: tl(devices)})
    send(pid, {:devices_updated, tl(devices)})
    assert_receive {:bridge_command, _, {:axis, :x, 16_384}}
    assert_receive {:bridge_command, _, {:button, 4, false}}
    refute_receive {:bridge_command, _, {:button, 5, false}}, 30
  end

  test "bridge exit degrades then retries with bounded backoff and ignores stale transition replies",
       %{agent: agent} do
    Agent.update(
      agent,
      &%{&1 | requested?: true, device_status: :compatible, bridge_results: [:ready, :ready]}
    )

    pid = start_manager(retry_delays: [5, 10])
    assert eventually(fn -> Manager.status(pid) == :active end)
    assert_receive {:bridge_started, ^pid}
    send(pid, {:virtual_joystick_bridge, {:exit, 1}})
    assert eventually(fn -> Manager.status(pid) == :degraded end)
    assert_receive {:bridge_started, ^pid}, 100
    assert eventually(fn -> Manager.status(pid) == :active end)

    send(pid, {:manager_transition_result, make_ref(), :enable, :ok})
    assert Manager.status(pid) == :active
  end

  test "device removal clears the stale bridge and follows compatible degraded recovery", %{
    agent: agent
  } do
    Agent.update(
      agent,
      &%{&1 | requested?: true, device_status: :compatible, bridge_results: [:ready, :ready]}
    )

    pid = start_manager(retry_delays: [5])
    assert eventually(fn -> Manager.status(pid) == :active end)
    assert_receive {:bridge_started, ^pid}
    old_bridge = :sys.get_state(pid).bridge_pid

    send(pid, {:virtual_joystick_bridge, {:device_removed, 1}})
    assert eventually(fn -> Manager.status(pid) == :degraded end)
    assert :sys.get_state(pid).bridge_pid == nil
    assert :sys.get_state(pid).axis_range == nil
    assert_receive {:bridge_started, ^pid}, 100
    assert eventually(fn -> Manager.status(pid) == :active end)
    refute :sys.get_state(pid).bridge_pid == old_bridge
  end

  test "retry exhaustion reaches error and disable cancels pending retry", %{agent: agent} do
    Agent.update(
      agent,
      &%{
        &1
        | requested?: true,
          device_status: :compatible,
          bridge_results: [:ready, {:error, :boom}, {:error, :boom}]
      }
    )

    pid = start_manager(retry_delays: [5, 10])
    assert eventually(fn -> Manager.status(pid) == :active end)
    assert_receive {:bridge_started, ^pid}
    send(pid, {:virtual_joystick_bridge, {:exit, 1}})
    assert eventually(fn -> Manager.status(pid) == :error end, 300)
    drain_bridge_starts(pid)

    Agent.update(agent, &%{&1 | bridge_results: [:ready]})
    assert :ok = Manager.disable(pid)
    assert eventually(fn -> Manager.status(pid) == :off end)
    refute_receive {:bridge_started, ^pid}, 30
  end

  test "disable cancels a scheduled bridge retry", %{agent: agent} do
    Agent.update(
      agent,
      &%{&1 | requested?: true, device_status: :compatible, bridge_results: [:ready, :ready]}
    )

    pid = start_manager(retry_delays: [100])
    assert eventually(fn -> Manager.status(pid) == :active end)
    assert_receive {:bridge_started, ^pid}
    send(pid, {:virtual_joystick_bridge, {:exit, 1}})
    assert eventually(fn -> Manager.status(pid) == :degraded end)
    assert :ok = Manager.disable(pid)
    assert eventually(fn -> Manager.status(pid) == :off end)
    refute_receive {:bridge_started, ^pid}, 150
  end

  test "terminate resets and shuts down enabled bridge without deleting device", %{agent: agent} do
    Agent.update(agent, &%{&1 | requested?: true, device_status: :compatible})
    pid = start_manager()
    assert eventually(fn -> Manager.status(pid) == :active end)
    GenServer.stop(pid)
    assert_receive {:bridge_command, bridge, :reset}
    assert_receive {:bridge_command, ^bridge, :shutdown}
    refute_receive :delete_called
  end

  defp start_manager(opts \\ []) do
    {:ok, pid} =
      Manager.start_link(
        Keyword.merge(
          [
            name: nil,
            platform: FakePlatform,
            context: FakeContext,
            configurator: FakeConfigurator,
            bridge: FakeBridge,
            serial: FakeSerial,
            inputs: FakeInputs,
            retry_delays: [250, 500, 1_000, 2_000, 4_000]
          ],
          opts
        )
      )

    pid
  end

  defp mappings do
    device = %Device{id: 1, config_id: 101}
    calibration = %Calibration{min_value: 0, max_value: 100, max_hardware_value: 100}

    axis_input = %Input{
      id: 10,
      pin: 5,
      input_type: :analog,
      device: device,
      calibration: calibration
    }

    button_input = %Input{id: 11, pin: 6, input_type: :button, device: device, calibration: nil}

    {
      %Mapping{
        id: 1,
        device_index: 1,
        target_type: :axis,
        axis: :x,
        inverted: false,
        input: axis_input
      },
      %Mapping{
        id: 2,
        device_index: 1,
        target_type: :button,
        button: 4,
        inverted: false,
        input: button_input
      }
    }
  end

  defp eventually(fun, timeout \\ 150) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_eventually(fun, deadline)
  end

  defp do_eventually(fun, deadline) do
    if fun.() do
      true
    else
      if System.monotonic_time(:millisecond) >= deadline do
        false
      else
        Process.sleep(2)
        do_eventually(fun, deadline)
      end
    end
  end

  defp drain_bridge_commands do
    receive do
      {:bridge_command, _, _} -> drain_bridge_commands()
    after
      0 -> :ok
    end
  end

  defp drain_bridge_starts(pid) do
    receive do
      {:bridge_started, ^pid} -> drain_bridge_starts(pid)
    after
      0 -> :ok
    end
  end
end
