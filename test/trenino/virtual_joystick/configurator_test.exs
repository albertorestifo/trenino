defmodule Trenino.VirtualJoystick.ConfiguratorTest do
  use ExUnit.Case, async: false

  alias Trenino.VirtualJoystick.Configurator
  alias Trenino.VirtualJoystick.Configurator.SystemAdapter

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

    def status(timeout) do
      update(fn state ->
        duration = List.first(state.status_durations) || 0
        durations = if state.status_durations == [], do: [], else: tl(state.status_durations)

        {probed_status, statuses, last_status} = next_status(state)
        status = if duration > timeout, do: :driver_missing, else: probed_status

        {status,
         %{
           state
           | statuses: statuses,
             last_status: last_status,
             status_durations: durations,
             now_ms: state.now_ms + min(duration, timeout),
             last_status_timeout: timeout
         }}
      end)
    end

    def configurator_path, do: get().configurator_path

    def mark_device_owned(owned) do
      update(fn state ->
        state = record(state, {:mark_device_owned, owned})
        state = if state.marker_result == :ok, do: %{state | device_owned: owned}, else: state
        {state.marker_result, state}
      end)
    end

    def elevate(path, arguments),
      do: update(fn state -> {state.result, record(state, {:elevate, path, arguments})} end)

    def sleep(milliseconds),
      do:
        update(fn state ->
          {:ok,
           state |> Map.update!(:now_ms, &(&1 + milliseconds)) |> record({:sleep, milliseconds})}
        end)

    def monotonic_time, do: get().now_ms

    defp get, do: Agent.get(agent(), & &1)
    defp update(fun), do: Agent.get_and_update(agent(), fun)
    defp agent, do: Application.fetch_env!(:trenino, :virtual_joystick_test_agent)
    defp record(state, event), do: Map.update!(state, :events, &(&1 ++ [event]))

    defp next_status(%{statuses: [status | rest]}), do: {status, rest, status}
    defp next_status(%{statuses: [], last_status: status}), do: {status, [], status}
  end

  setup do
    {:ok, agent} =
      Agent.start_link(fn ->
        %{
          statuses: [:device_missing, :compatible],
          last_status: :compatible,
          configurator_path: {:ok, ~S(C:\Program Files\Trenino\resources\vJoyConfig.exe)},
          result: {:ok, 0},
          marker_result: :ok,
          device_owned: false,
          events: [],
          now_ms: 0,
          status_durations: [],
          last_status_timeout: nil
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

    assert Agent.get(agent, & &1.device_owned)
    assert {:mark_device_owned, true} in Agent.get(agent, & &1.events)
  end

  test "delete targets only device 1", %{agent: agent} do
    Agent.update(
      agent,
      &%{&1 | statuses: [:compatible, :device_missing], last_status: :device_missing}
    )

    assert Configurator.delete() == :ok
    assert [{:elevate, _, ["-d", "1"]} | _] = Agent.get(agent, & &1.events)
    refute Agent.get(agent, & &1.device_owned)
    assert {:mark_device_owned, false} in Agent.get(agent, & &1.events)
  end

  test "does not record device ownership until creation is confirmed", %{agent: agent} do
    Agent.update(agent, &%{&1 | statuses: [:device_missing], last_status: :device_missing})

    assert Configurator.create() == {:error, :timeout}
    refute Agent.get(agent, & &1.device_owned)
    refute {:mark_device_owned, true} in Agent.get(agent, & &1.events)
  end

  test "marker persistence failure is explicit after confirmed creation", %{agent: agent} do
    Agent.update(agent, &%{&1 | marker_result: {:error, :marker_write_failed}})

    assert Configurator.create() == {:error, :marker_write_failed}
    refute Agent.get(agent, & &1.device_owned)
  end

  test "already satisfied operations are idempotent and do not elevate", %{agent: agent} do
    Agent.update(agent, &%{&1 | statuses: [:compatible], last_status: :compatible})
    assert Configurator.create() == :ok
    assert Agent.get(agent, & &1.events) == []

    Agent.update(agent, &%{&1 | statuses: [:device_missing], last_status: :device_missing})
    assert Configurator.delete() == :ok
    assert Agent.get(agent, & &1.events) == [{:mark_device_owned, false}]
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

  test "device ownership uses only the fixed current-user registry marker" do
    assert SystemAdapter.ownership_marker_arguments(true) == [
             "ADD",
             ~S(HKCU\Software\Trenino),
             "/v",
             "VJoyDevice1CreatedByTrenino",
             "/t",
             "REG_DWORD",
             "/d",
             "1",
             "/f"
           ]

    assert SystemAdapter.ownership_marker_arguments(false) == [
             "DELETE",
             ~S(HKCU\Software\Trenino),
             "/v",
             "VJoyDevice1CreatedByTrenino",
             "/f"
           ]
  end

  test "deleting an absent ownership marker is locale-independent and idempotent" do
    assert SystemAdapter.normalize_marker_exit(1, true) == :ok
    assert SystemAdapter.normalize_marker_exit(1, false) == {:error, :marker_write_failed}
    assert SystemAdapter.normalize_marker_exit(5, true) == {:error, :marker_write_failed}
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

  test "slow status probes consume the monotonic deadline", %{agent: agent} do
    Agent.update(
      agent,
      &%{&1 | statuses: [:compatible], status_durations: [150], now_ms: 10, events: []}
    )

    assert Configurator.wait_for(:compatible, 100) == {:error, :timeout}
    assert Agent.get(agent, & &1.events) == []
    assert Agent.get(agent, & &1.last_status_timeout) == 100
  end

  test "trusted path validation rejects an intermediate symlink escape" do
    root = Path.join(System.tmp_dir!(), "trenino-trusted-#{System.unique_integer([:positive])}")

    outside =
      Path.join(System.tmp_dir!(), "trenino-outside-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    File.mkdir_p!(outside)
    File.write!(Path.join(outside, "vJoyConfig.exe"), "test")
    File.ln_s!(outside, Path.join(root, "resources"))

    on_exit(fn ->
      File.rm_rf!(root)
      File.rm_rf!(outside)
    end)

    escaped = Path.join([root, "resources", "vJoyConfig.exe"])
    refute SystemAdapter.trusted_file?(escaped, [root])
  end

  test "trusted path validation rejects a Windows-style reparse component" do
    root = Path.join(System.tmp_dir!(), "trenino-root-#{System.unique_integer([:positive])}")
    resources = Path.join(root, "resources")
    File.mkdir_p!(resources)
    candidate = Path.join(resources, "vJoyConfig.exe")
    File.write!(candidate, "test")
    on_exit(fn -> File.rm_rf!(root) end)

    reparse_probe = &(&1 == resources)
    refute SystemAdapter.trusted_file?(candidate, [root], reparse_probe)
  end

  test "trusted validation starts above a linked packaged resource parent" do
    anchor = Path.join(System.tmp_dir!(), "trenino-anchor-#{System.unique_integer([:positive])}")

    outside =
      Path.join(System.tmp_dir!(), "trenino-parent-outside-#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(anchor, "app"))
    File.mkdir_p!(Path.join(outside, "resources"))
    candidate = Path.join([outside, "resources", "vJoyConfig.exe"])
    File.write!(candidate, "test")
    File.ln_s!(outside, Path.join([anchor, "app", "priv"]))

    on_exit(fn ->
      File.rm_rf!(anchor)
      File.rm_rf!(outside)
    end)

    escaped = Path.join([anchor, "app", "priv", "resources", "vJoyConfig.exe"])
    declared_root = Path.join([anchor, "app", "priv", "resources"])
    refute SystemAdapter.trusted_file?(escaped, [{anchor, declared_root}])
  end

  test "the status deadline includes a slow native reparse probe" do
    anchor =
      Path.join(System.tmp_dir!(), "trenino-slow-probe-#{System.unique_integer([:positive])}")

    File.mkdir_p!(anchor)
    candidate = Path.join(anchor, "vJoyInterface.dll")
    File.write!(candidate, "test")
    on_exit(fn -> File.rm_rf!(anchor) end)

    shell = System.find_executable("sh")

    slow_reparse_probe = fn _path ->
      assert {:error, {:timeout, _pid, _output}} =
               SystemAdapter.run_status_executable(shell, ["-c", "sleep 30"])

      false
    end

    operation = fn ->
      if SystemAdapter.trusted_file?(candidate, [anchor], slow_reparse_probe),
        do: :compatible,
        else: :driver_missing
    end

    started = System.monotonic_time(:millisecond)
    assert SystemAdapter.status(40, operation) == :driver_missing
    assert System.monotonic_time(:millisecond) - started < 140
  end

  test "a timed out external command is terminated and reaped" do
    if match?({:unix, _}, :os.type()) do
      shell = System.find_executable("sh")

      assert {:error, {:timeout, pid, output}} =
               SystemAdapter.run_executable(
                 shell,
                 ["-c", "sleep 30 & child=$!; echo $child; wait"],
                 30
               )

      child_pid = output |> String.trim() |> String.to_integer()

      for terminated_pid <- [pid, child_pid] do
        {_output, status} =
          System.cmd("/bin/kill", ["-0", Integer.to_string(terminated_pid)],
            stderr_to_stdout: true
          )

        assert status != 0
      end
    end
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
