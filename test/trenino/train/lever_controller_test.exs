defmodule Trenino.Train.LeverControllerTest do
  # Shared sandbox: the controller process needs Sandbox.allow/3.
  use Trenino.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Hardware
  alias Trenino.Serial.Connection.DeviceConnection
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.LeverController

  @endpoint "CurrentDrivableActor/Throttle(Lever).InputValue"
  setup :set_mimic_global

  setup do
    Mimic.stub(Circuits.UART, :enumerate, fn -> %{} end)
    Mimic.stub(Trenino.Serial.Connection, :list_devices, fn -> [] end)
    Mimic.stub(Trenino.Serial.Connection, :subscribe, fn -> :ok end)
    {:ok, controller} = start_supervised(LeverController)

    Sandbox.allow(Trenino.Repo, self(), controller)

    :ok
  end

  describe "smooth lever updates" do
    setup %{test: test} do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Latency Train",
          identifiers: [%{identifier: "latency_train_#{System.unique_integer([:positive])}"}]
        })

      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, lever_config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "CurrentDrivableActor/Throttle(Lever).Min",
          max_endpoint: "CurrentDrivableActor/Throttle(Lever).Max",
          value_endpoint: @endpoint,
          lever_type: :continuous
        })

      {:ok, _notch} =
        TrainContext.create_notch(lever_config.id, %{
          index: 0,
          type: :linear,
          input_min: 0.0,
          input_max: 1.0,
          sim_input_min: 0.0,
          sim_input_max: 1.0,
          min_value: 0.0,
          max_value: 1.0
        })

      {:ok, device} = Hardware.create_device(%{name: "Pro Micro #{test}"})

      {:ok, input} =
        Hardware.create_input(device.id, %{
          pin: 2,
          input_type: :analog,
          sensitivity: 1,
          name: "Throttle pot"
        })

      {:ok, _calibration} =
        Hardware.save_calibration(input.id, %{
          max_hardware_value: 1023,
          min_value: 0,
          max_value: 1000,
          has_rollover: false,
          is_inverted: false
        })

      {:ok, _binding} = TrainContext.bind_input(lever_config.id, input.id)

      device_conn = %DeviceConnection{
        port: "/dev/cu.usbmodem#{System.unique_integer([:positive])}",
        status: :connected,
        device_config_id: device.config_id
      }

      Mimic.stub(Trenino.Serial.Connection, :list_devices, fn -> [device_conn] end)
      send(Process.whereis(LeverController), {:train_changed, train})
      send(Process.whereis(LeverController), {:devices_updated, [device_conn]})
      LeverController.get_state()

      %{port: device_conn.port, pin: input.pin}
    end

    test "sends the latest jittered value instead of draining a FIFO of stale writes", %{
      port: port,
      pin: pin
    } do
      test_pid = self()
      client = %Client{base_url: "http://localhost:31270", api_key: "test"}

      Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      Mimic.stub(Client, :set, fn ^client, @endpoint, value ->
        send(test_pid, {:set_started, value, self()})

        receive do
          :release_set -> {:ok, %{"Result" => "Success"}}
        after
          2_000 -> {:error, :timeout}
        end
      end)

      controller = Process.whereis(LeverController)

      # First sample blocks inside the slow simulator write.
      send(controller, {:input_value_updated, port, pin, 100})
      assert_receive {:set_started, 0.1, writer}, 1_000

      # Jitter arrives while that write is in flight. A FIFO would later send
      # every intermediate sample; the controller must keep only the latest.
      for raw <- [200, 400, 600, 800] do
        send(controller, {:input_value_updated, port, pin, raw})
      end

      send(writer, :release_set)
      assert_receive {:set_started, 0.8, writer}, 1_000
      send(writer, :release_set)

      refute_receive {:set_started, _, _}, 100
    end

    test "reconnect retries a retained failed write", %{port: port, pin: pin} do
      test_pid = self()
      client = %Client{base_url: "http://localhost:31270", api_key: "test"}

      Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      Mimic.stub(Client, :set, fn ^client, @endpoint, value ->
        send(test_pid, {:set_started, value, self()})
        receive do: (:release_set -> {:error, :disconnected})
      end)

      controller = Process.whereis(LeverController)
      send(controller, {:input_value_updated, port, pin, 500})
      assert_receive {:set_started, 0.5, writer}, 1_000

      send(writer, :release_set)
      refute_receive {:set_started, _, _}, 100

      send(
        controller,
        {:simulator_status_changed, %ConnectionState{status: :connected, client: client}}
      )

      assert_receive {:set_started, 0.5, writer}, 1_000
      send(writer, :release_set)
      refute_receive {:set_started, _, _}, 100
    end

    test "retries a final transient failure without another input", context do
      {controller, writer} = start_blocked_write(context)
      send(writer, {:finish, {:error, :timeout}})
      refute_receive {:attempt, _, _}, 100
      assert_receive {:attempt, 0.5, retry}, 1_000
      send(retry, {:finish, {:ok, %{}}})
      refute_receive {:attempt, _, _}, 1_000
      assert LeverController.get_state().pending == %{}
      assert Process.alive?(controller)
    end

    test "reconnect before an old writer fails still delivers the newest target", context do
      {controller, writer} = start_blocked_write(context)
      send(controller, {:input_value_updated, context.port, context.pin, 800})
      send(controller, {:simulator_status_changed, %ConnectionState{status: :connected}})
      LeverController.get_state()
      send(writer, {:finish, {:error, :timeout}})
      assert_receive {:attempt, 0.8, retry}, 1_000
      send(retry, {:finish, {:ok, %{}}})
      refute_receive {:attempt, _, _}, 300
    end

    test "reconnect during the final allowed attempt restores a retry budget", context do
      {controller, writer} = start_blocked_write(context)

      final_writer =
        Enum.reduce(1..3, writer, fn _, current ->
          send(current, {:finish, {:error, :timeout}})
          assert_receive {:attempt, 0.5, retry}, 1_500
          retry
        end)

      send(controller, {:simulator_status_changed, %ConnectionState{status: :connected}})
      LeverController.get_state()
      send(final_writer, {:finish, {:error, :timeout}})
      assert_receive {:attempt, 0.5, retry}, 1_000
      send(retry, {:finish, {:ok, %{}}})
    end

    test "a pending retry coalesces fresh input without bypassing the delay", context do
      {controller, writer} = start_blocked_write(context)
      send(writer, {:finish, {:error, :timeout}})
      wait_for_writer_release(controller)

      for raw <- [600, 700, 900],
          do: send(controller, {:input_value_updated, context.port, context.pin, raw})

      refute_receive {:attempt, _, _}, 100
      assert_receive {:attempt, 0.9, retry}, 1_000
      send(retry, {:finish, {:ok, %{}}})
    end

    test "persistent failures exhaust a bounded retry budget", context do
      {_controller, writer} = start_blocked_write(context)
      send(writer, {:finish, {:error, :timeout}})

      for _ <- 1..3 do
        assert_receive {:attempt, 0.5, retry}, 1_500
        send(retry, {:finish, {:error, :timeout}})
      end

      refute_receive {:attempt, _, _}, 1_000
    end

    test "disconnect suspends retries until reconnect and retains the latest input", context do
      {controller, writer} = start_blocked_write(context)
      send(writer, {:finish, {:error, :timeout}})
      wait_for_writer_release(controller)

      Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
        %ConnectionState{status: :disconnected}
      end)

      send(controller, {:simulator_status_changed, %ConnectionState{status: :disconnected}})

      for raw <- [600, 700, 900],
          do: send(controller, {:input_value_updated, context.port, context.pin, raw})

      refute_receive {:attempt, _, _}, 500
      connect_simulator()
      send(controller, {:simulator_status_changed, %ConnectionState{status: :connected}})
      assert_receive {:attempt, 0.9, retry}, 1_000
      send(retry, {:finish, {:ok, %{}}})
    end

    for lifecycle <- [:reload, :deactivate, :change_train] do
      @lifecycle lifecycle
      test "#{lifecycle} cancels a scheduled retry", context do
        {controller, writer} = start_blocked_write(context)
        send(writer, {:finish, {:error, :timeout}})
        wait_for_writer_release(controller)
        state = LeverController.get_state()
        assert map_size(Map.get(state, :retries, %{})) == 1
        [{_, %{timer: timer}}] = Map.to_list(state.retries)
        assert is_reference(timer)

        case @lifecycle do
          :reload -> LeverController.reload_bindings()
          :deactivate -> send(controller, {:train_changed, nil})
          :change_train -> send(controller, {:train_changed, state.active_train})
        end

        assert LeverController.get_state().pending == %{}
        assert Process.read_timer(timer) == false
        refute_receive {:attempt, _, _}, 500
      end
    end

    test "a crashed writer releases the lever for the next input", %{port: port, pin: pin} do
      test_pid = self()
      client = %Client{base_url: "http://localhost:31270", api_key: "test"}

      Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      Mimic.stub(Client, :set, fn _, _, value ->
        send(test_pid, {:writer, value, self()})
        receive do: (:finish -> {:ok, %{}})
      end)

      controller = Process.whereis(LeverController)
      send(controller, {:input_value_updated, port, pin, 100})
      assert_receive {:writer, 0.1, writer}
      monitor = Process.monitor(writer)
      Process.exit(writer, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^writer, :killed}
      # Wait for the controller to handle its own task monitor signal.
      wait_for_writer_release(controller)
      send(controller, {:input_value_updated, port, pin, 800})
      assert_receive {:writer, 0.8, new_writer}, 1_000
      send(new_writer, :finish)
    end

    test "reloading bindings terminates obsolete in-flight writers", %{port: port, pin: pin} do
      test_pid = self()
      client = %Client{base_url: "http://localhost:31270", api_key: "test"}

      Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      Mimic.stub(Client, :set, fn _, _, _ ->
        send(test_pid, {:writer, self()})
        receive do: (:finish -> {:ok, %{}})
      end)

      send(LeverController, {:input_value_updated, port, pin, 100})
      assert_receive {:writer, writer}
      ref = Process.monitor(writer)
      LeverController.reload_bindings()
      assert_receive {:DOWN, ^ref, :process, ^writer, _}, 1_000
      assert LeverController.get_state().pending == %{}
    end

    test "disconnected writes wait for a lifecycle event", %{port: port, pin: pin} do
      test_pid = self()

      Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
        send(test_pid, :status_checked)
        %ConnectionState{status: :disconnected}
      end)

      send(LeverController, {:input_value_updated, port, pin, 500})
      assert_receive :status_checked
      refute_receive :status_checked, 100
    end
  end

  defp connect_simulator do
    client = %Client{base_url: "http://localhost:31270", api_key: "test"}

    Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
      %ConnectionState{status: :connected, client: client}
    end)

    client
  end

  defp start_blocked_write(context) do
    client = connect_simulator()
    test_pid = self()

    Mimic.stub(Client, :set, fn ^client, @endpoint, value ->
      send(test_pid, {:attempt, value, self()})
      receive do: ({:finish, result} -> result)
    end)

    controller = Process.whereis(LeverController)
    send(controller, {:input_value_updated, context.port, context.pin, 500})
    assert_receive {:attempt, 0.5, writer}, 1_000
    {controller, writer}
  end

  defp wait_for_writer_release(controller, attempts \\ 20)

  defp wait_for_writer_release(_controller, 0),
    do: flunk("crashed writer retained its pending slot")

  defp wait_for_writer_release(controller, attempts) do
    if Enum.any?(LeverController.get_state().pending, fn {_, {_, _, task}} ->
         match?(%Task{}, task)
       end) do
      Process.sleep(5)
      wait_for_writer_release(controller, attempts - 1)
    end
  end
end
