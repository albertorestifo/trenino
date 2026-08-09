defmodule Trenino.VirtualJoystick.BridgeTest do
  use ExUnit.Case, async: false

  alias Trenino.Test.FakeVirtualJoystick, as: Fake
  alias Trenino.VirtualJoystick.Bridge
  alias Trenino.VirtualJoystick.Bridge.PortAdapter

  setup do
    Application.put_env(:trenino, :virtual_joystick_fake_test, self())

    on_exit(fn ->
      Application.delete_env(:trenino, :virtual_joystick_fake_test)
      System.delete_env("APP_PATH")
    end)

    :ok
  end

  test "discovers APP_PATH before bundled and Cargo executables" do
    directory = Path.join(System.tmp_dir!(), "trenino-vjoy-#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)
    executable = Path.join(directory, Bridge.binary_name())
    File.write!(executable, "")
    System.put_env("APP_PATH", directory)
    on_exit(fn -> File.rm_rf!(directory) end)

    assert {:ok, ^executable} = Bridge.executable_path()
  end

  test "uses the Cargo binary name and launches the feeder in serve mode" do
    expected =
      if match?({:win32, _}, :os.type()), do: "virtual_joystick.exe", else: "virtual_joystick"

    assert Bridge.binary_name() == expected

    assert {:ok, bridge} =
             Bridge.start_link(
               owner: self(),
               adapter: Fake,
               executable: "/fake/virtual_joystick",
               timeout: 100
             )

    assert_receive {:opened, ^bridge, _handle, "/fake/virtual_joystick", opts}
    assert opts[:args] == ["serve"]
  end

  test "passes only the trusted resolved vJoy interface path to the Windows feeder" do
    dll = ~S(C:\Program Files\Trenino\resources\vJoyInterface.dll)
    resolver = Module.concat(__MODULE__, InterfaceResolver)
    Application.put_env(:trenino, :virtual_joystick_test_dll, dll)
    on_exit(fn -> Application.delete_env(:trenino, :virtual_joystick_test_dll) end)

    assert {:ok, ["serve", "--vjoy-interface", ^dll]} =
             Bridge.feeder_arguments(true, resolver)

    assert {:ok, ["serve"]} = Bridge.feeder_arguments(false, resolver)
  end

  defmodule InterfaceResolver do
    def interface_path,
      do: {:ok, Application.fetch_env!(:trenino, :virtual_joystick_test_dll)}
  end

  test "production adapter normalizes a successful Port.command result" do
    {executable, args} =
      case :os.type() do
        {:win32, _} -> {System.find_executable("cmd"), ["/Q", "/D", "/C", "set /p line="]}
        _ -> {System.find_executable("sh"), ["-c", "IFS= read -r line"]}
      end

    if executable do
      assert {:ok, port} =
               PortAdapter.open(self(), executable, args: args)

      assert :ok = PortAdapter.send_line(port, "hello")
      PortAdapter.close(port)
    end
  end

  test "handshakes with protocol version 1 and reports ready" do
    {bridge, handle} = start_bridge()
    assert_sent(handle, %{"command" => "hello", "protocol" => 1})

    Fake.stdout(
      bridge,
      handle,
      ~s({"event":"ready","protocol":1,"device":1,"axis_min":0,"axis_max":32768}\n)
    )

    assert_receive {:virtual_joystick_bridge,
                    {:ready, %{device: 1, axis_min: 0, axis_max: 32_768}}}

    assert %{state: :ready, protocol: 1, device: 1} = Bridge.status(bridge)
  end

  test "rejects a protocol mismatch without crashing callers" do
    {bridge, handle} = start_bridge()

    Fake.stdout(
      bridge,
      handle,
      ~s({"event":"ready","protocol":2,"device":1,"axis_min":0,"axis_max":32768}\n)
    )

    assert_receive {:virtual_joystick_bridge, {:error, {:protocol_mismatch, 2}}}
    assert {:error, {:protocol_mismatch, 2}} = Bridge.set_axis(bridge, :x, 12)
  end

  test "fails the handshake on uncorrelated sidecar errors" do
    for event <- ["invalid_command", "error"] do
      {bridge, handle} = start_bridge()

      Fake.stdout(
        bridge,
        handle,
        Jason.encode!(%{event: event, code: "invalid_command", message: "unsupported protocol"}) <>
          "\n"
      )

      assert_receive {:virtual_joystick_bridge,
                      {:error, {:feeder_error, "invalid_command", "unsupported protocol"}}}

      assert {:error, {:feeder_error, "invalid_command", "unsupported protocol"}} =
               Bridge.set_axis(bridge, :x, 12)
    end
  end

  test "correlates command acknowledgements by request id" do
    {bridge, handle} = ready_bridge()
    task = Task.async(fn -> Bridge.set_axis(bridge, :x, 123) end)
    command = assert_sent(handle, %{"command" => "set_axis", "axis" => "x", "value" => 123})

    Fake.stdout(
      bridge,
      handle,
      Jason.encode!(%{event: "applied", request_id: command["request_id"]}) <> "\n"
    )

    assert :ok = Task.await(task)
  end

  test "keeps only the newest pending update per control" do
    {bridge, handle} = ready_bridge()
    first = Task.async(fn -> Bridge.set_axis(bridge, :x, 10) end)
    first_command = assert_sent(handle, %{"command" => "set_axis", "value" => 10})

    replaced = Task.async(fn -> Bridge.set_axis(bridge, :x, 20) end)
    newest = Task.async(fn -> Bridge.set_axis(bridge, :x, 30) end)
    assert {:error, :superseded} = Task.await(replaced)
    refute_receive {:sent, ^handle, _}, 20

    ack(bridge, handle, first_command)
    assert :ok = Task.await(first)
    newest_command = assert_sent(handle, %{"command" => "set_axis", "value" => 30})
    ack(bridge, handle, newest_command)
    assert :ok = Task.await(newest)
  end

  test "does not parse stderr as protocol output" do
    {bridge, handle} = ready_bridge()
    Fake.stderr(bridge, handle, ~s({"event":"device_removed","device":1}\n))
    refute_receive {:virtual_joystick_bridge, {:device_removed, _}}
    assert Process.alive?(bridge)
  end

  test "rejects malformed and oversized stdout and remains alive" do
    {bridge, handle} = ready_bridge()
    Fake.stdout(bridge, handle, "not-json\n")
    assert_receive {:virtual_joystick_bridge, {:protocol_error, :malformed_json}}

    Fake.stdout(bridge, handle, String.duplicate("x", 16 * 1024 + 1))
    assert_receive {:virtual_joystick_bridge, {:protocol_error, :line_too_long}}
    assert Process.alive?(bridge)
  end

  test "discards an oversized line through its terminating newline" do
    {bridge, handle} = start_bridge()
    assert_sent(handle, %{"command" => "hello"})
    Fake.stdout(bridge, handle, String.duplicate("x", 16 * 1024 + 1))
    assert_receive {:virtual_joystick_bridge, {:protocol_error, :line_too_long}}

    ready = ~s({"event":"ready","protocol":1,"device":1,"axis_min":0,"axis_max":32768}\n)
    Fake.stdout(bridge, handle, ready)
    refute_receive {:virtual_joystick_bridge, {:ready, _}}
    refute_receive {:virtual_joystick_bridge, {:protocol_error, _}}

    Fake.stdout(bridge, handle, ready)
    assert_receive {:virtual_joystick_bridge, {:ready, _}}
  end

  test "device removal immediately resolves its correlated caller" do
    {bridge, handle} = ready_bridge()
    task = Task.async(fn -> Bridge.set_axis(bridge, :z, 55) end)
    command = assert_sent(handle, %{"command" => "set_axis"})

    Fake.stdout(
      bridge,
      handle,
      Jason.encode!(%{event: "device_removed", device: 1, request_id: command["request_id"]}) <>
        "\n"
    )

    assert {:error, :device_removed} = Task.await(task)
    assert_receive {:virtual_joystick_bridge, {:device_removed, 1}}
  end

  test "returns tagged timeout errors and ignores late acknowledgements" do
    {bridge, handle} = ready_bridge()
    task = Task.async(fn -> Bridge.set_button(bridge, 2, true) end)
    command = assert_sent(handle, %{"command" => "set_button", "button" => 2})
    assert {:error, :timeout} = Task.await(task)

    ack(bridge, handle, command)
    assert Process.alive?(bridge)
  end

  test "reports an unexpected feeder exit and fails outstanding callers" do
    {bridge, handle} = ready_bridge()
    task = Task.async(fn -> Bridge.set_axis(bridge, :y, 9) end)
    assert_sent(handle, %{"command" => "set_axis"})
    Fake.exit(bridge, handle, 7)

    assert {:error, {:process_exit, 7}} = Task.await(task)
    assert_receive {:virtual_joystick_bridge, {:exit, 7}}
  end

  test "sends reset with a correlated acknowledgement" do
    {bridge, handle} = ready_bridge()
    task = Task.async(fn -> Bridge.reset(bridge) end)
    command = assert_sent(handle, %{"command" => "reset", "device" => 1})
    ack(bridge, handle, command)
    assert :ok = Task.await(task)
  end

  test "shuts down gracefully" do
    {bridge, handle} = ready_bridge()
    assert :ok = Bridge.shutdown(bridge)
    assert_sent(handle, %{"command" => "shutdown"})
    Fake.stdout(bridge, handle, ~s({"event":"stopped"}\n))
    assert_receive {:closed, ^handle}
    refute Process.alive?(bridge)
  end

  defp start_bridge do
    assert {:ok, bridge} =
             Bridge.start_link(
               owner: self(),
               adapter: Fake,
               executable: "/fake/virtual_joystick",
               timeout: 100
             )

    assert_receive {:opened, ^bridge, handle, "/fake/virtual_joystick", _opts}
    {bridge, handle}
  end

  defp ready_bridge do
    {bridge, handle} = start_bridge()
    assert_sent(handle, %{"command" => "hello"})

    Fake.stdout(
      bridge,
      handle,
      ~s({"event":"ready","protocol":1,"device":1,"axis_min":0,"axis_max":32768}\n)
    )

    assert_receive {:virtual_joystick_bridge, {:ready, _}}
    {bridge, handle}
  end

  defp assert_sent(handle, expected) do
    assert_receive {:sent, ^handle, line}
    decoded = Jason.decode!(line)
    assert Map.take(decoded, Map.keys(expected)) == expected
    decoded
  end

  defp ack(bridge, handle, command) do
    Fake.stdout(
      bridge,
      handle,
      Jason.encode!(%{event: "applied", request_id: command["request_id"]}) <> "\n"
    )
  end
end
