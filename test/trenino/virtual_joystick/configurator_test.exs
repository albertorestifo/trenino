defmodule Trenino.VirtualJoystick.ConfiguratorTest do
  use ExUnit.Case, async: false

  alias Trenino.VirtualJoystick.Configurator

  defmodule FakePlatform do
    def windows?, do: Application.fetch_env!(:trenino, :virtual_joystick_test_windows)
  end

  defmodule FakeSystem do
    def status do
      update(fn state ->
        case state.statuses do
          [status | rest] -> {status, %{state | statuses: rest}}
          [] -> {state.last_status, state}
        end
      end)
    end

    def configurator_path, do: get().configurator_path

    def elevate(path, arguments),
      do: update(fn state -> {state.result, record(state, {:elevate, path, arguments})} end)

    def sleep(milliseconds),
      do: update(fn state -> {:ok, record(state, {:sleep, milliseconds})} end)

    defp get, do: Agent.get(agent(), & &1)
    defp update(fun), do: Agent.get_and_update(agent(), fun)
    defp agent, do: Application.fetch_env!(:trenino, :virtual_joystick_test_agent)
    defp record(state, event), do: Map.update!(state, :events, &(&1 ++ [event]))
  end

  setup do
    {:ok, agent} =
      Agent.start_link(fn ->
        %{
          statuses: [:device_missing, :compatible],
          last_status: :compatible,
          configurator_path: {:ok, ~S(C:\Program Files\Trenino\resources\vJoyConfig.exe)},
          result: {:ok, 0},
          events: []
        }
      end)

    Application.put_env(:trenino, :virtual_joystick_test_agent, agent)
    Application.put_env(:trenino, :virtual_joystick_test_windows, true)
    Application.put_env(:trenino, :virtual_joystick_platform, FakePlatform)
    Application.put_env(:trenino, :virtual_joystick_system_adapter, FakeSystem)

    on_exit(fn ->
      for key <- [
            :virtual_joystick_test_agent,
            :virtual_joystick_test_windows,
            :virtual_joystick_platform,
            :virtual_joystick_system_adapter
          ],
          do: Application.delete_env(:trenino, key)
    end)

    %{agent: agent}
  end

  test "non-Windows systems short-circuit without probing or elevation", %{agent: agent} do
    Application.put_env(:trenino, :virtual_joystick_test_windows, false)

    assert Configurator.status() == :driver_missing
    assert Configurator.create() == {:error, :unsupported}
    assert Configurator.delete() == {:error, :unsupported}
    assert Agent.get(agent, & &1.events) == []
  end

  test "reports every device status returned by the adapter", %{agent: agent} do
    for status <- [:driver_missing, :device_missing, :compatible, :incompatible, :busy] do
      Agent.update(agent, &%{&1 | statuses: [status], last_status: status})
      assert Configurator.status() == status
    end
  end

  test "create uses only the fixed Trenino descriptor", %{agent: agent} do
    assert Configurator.create() == :ok

    assert [{:elevate, path, arguments} | _] = Agent.get(agent, & &1.events)
    assert path == ~S(C:\Program Files\Trenino\resources\vJoyConfig.exe)

    assert arguments == [
             "1",
             "-a",
             "x",
             "y",
             "z",
             "rx",
             "ry",
             "rz",
             "sl0",
             "sl1",
             "-b",
             "32",
             "-p",
             "0"
           ]
  end

  test "delete targets only device 1", %{agent: agent} do
    Agent.update(
      agent,
      &%{&1 | statuses: [:compatible, :device_missing], last_status: :device_missing}
    )

    assert Configurator.delete() == :ok
    assert [{:elevate, _, ["-d", "1"]} | _] = Agent.get(agent, & &1.events)
  end

  test "already satisfied operations are idempotent and do not elevate", %{agent: agent} do
    Agent.update(agent, &%{&1 | statuses: [:compatible], last_status: :compatible})
    assert Configurator.create() == :ok
    assert Agent.get(agent, & &1.events) == []

    Agent.update(agent, &%{&1 | statuses: [:device_missing], last_status: :device_missing})
    assert Configurator.delete() == :ok
    assert Agent.get(agent, & &1.events) == []
  end

  test "hostile environment text cannot enter elevated executable arguments", %{agent: agent} do
    hostile = ~S(';$env:PWNED='yes';#)
    System.put_env("VJOY_CONFIG_ARGS", hostile)
    System.put_env("VJOY_CONFIG_PATH", hostile)

    on_exit(fn ->
      System.delete_env("VJOY_CONFIG_ARGS")
      System.delete_env("VJOY_CONFIG_PATH")
    end)

    assert Configurator.create() == :ok
    [{:elevate, path, arguments} | _] = Agent.get(agent, & &1.events)
    refute String.contains?(path, hostile)
    refute Enum.any?(arguments, &String.contains?(&1, hostile))
  end

  test "maps Windows UAC cancellation", %{agent: agent} do
    Agent.update(agent, &%{&1 | result: {:error, 1223}})
    assert Configurator.create() == {:error, :uac_cancelled}
  end

  test "returns a nonzero configurator exit", %{agent: agent} do
    Agent.update(agent, &%{&1 | result: {:ok, 7}})
    assert Configurator.create() == {:error, {:process_exit, 7}}
  end

  test "waits for device arrival and removal", %{agent: agent} do
    Agent.update(agent, &%{&1 | statuses: [:device_missing, :device_missing, :compatible]})
    assert Configurator.wait_for(:compatible, 250) == :ok
    assert Agent.get(agent, & &1.events) == [{:sleep, 100}, {:sleep, 100}]

    Agent.update(agent, &%{&1 | statuses: [:compatible, :device_missing], events: []})
    assert Configurator.wait_for(:device_missing, 100) == :ok
  end

  test "bounded polling times out", %{agent: agent} do
    Agent.update(agent, &%{&1 | statuses: [], last_status: :device_missing})
    assert Configurator.wait_for(:compatible, 200) == {:error, :timeout}
    assert Agent.get(agent, & &1.events) == [{:sleep, 100}, {:sleep, 100}]
  end

  test "create refuses incompatible and busy devices without elevation", %{agent: agent} do
    for status <- [:incompatible, :busy] do
      Agent.update(agent, &%{&1 | statuses: [status], last_status: status, events: []})
      assert Configurator.create() == {:error, status}
      assert Agent.get(agent, & &1.events) == []
    end
  end

  test "missing trusted configurator and driver failures are explicit", %{agent: agent} do
    Agent.update(agent, &%{&1 | configurator_path: {:error, :configurator_not_found}})
    assert Configurator.create() == {:error, :configurator_not_found}

    Agent.update(
      agent,
      &%{&1 | statuses: [:driver_missing], last_status: :driver_missing, events: []}
    )

    assert Configurator.create() == {:error, :driver_missing}
    assert Agent.get(agent, & &1.events) == []
  end
end
