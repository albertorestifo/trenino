defmodule Trenino.Train.SelectorControllerTest do
  # Shared sandbox: the controller process needs Sandbox.allow/3.
  use Trenino.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Keyboard
  alias Trenino.Serial.Connection.DeviceConnection
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.Detection
  alias Trenino.Train.Detection.State, as: DetectionState
  alias Trenino.Train.{SelectorController, SelectorMapper}

  @client %Client{base_url: "http://localhost:31270", api_key: "test"}
  @endpoint "CurrentDrivableActor/Headlights.InputValue"

  # Calibration 0..1000, so a raw reading of N normalizes to N / 1000.
  # Even split of 3: [0.0, 0.3], [0.37, 0.63], [0.7, 1.0]
  @pos0 100
  @pos1 500
  @pos2 800
  @gap 340

  setup :set_mimic_global

  setup do
    :sys.replace_state(Process.whereis(Detection), fn _state -> %DetectionState{} end)

    test_pid = self()

    Mimic.stub(Circuits.UART, :enumerate, fn -> %{} end)
    Mimic.stub(Trenino.Serial.Connection, :subscribe, fn -> :ok end)
    Mimic.stub(ConfigurationManager, :subscribe_input_values, fn _port -> :ok end)
    Mimic.stub(ConfigurationManager, :get_input_values, fn _port -> %{} end)
    stub_simulator(:connected)

    Mimic.stub(Client, :set, fn @client, endpoint, value ->
      send(test_pid, {:set, endpoint, value})
      {:ok, %{"Result" => "Success"}}
    end)

    Mimic.stub(Keyboard, :tap, fn keystroke ->
      send(test_pid, {:tap, keystroke})
      :ok
    end)

    {:ok, train} =
      TrainContext.create_train(%{
        name: "Selector Train",
        identifiers: [%{identifier: "selector_train_#{System.unique_integer([:positive])}"}]
      })

    {:ok, element} = TrainContext.create_element(train.id, %{name: "Lights", type: :selector})
    {:ok, device} = Hardware.create_device(%{name: "Pro Micro"})

    {:ok, input} =
      Hardware.create_input(device.id, %{pin: 3, input_type: :analog, sensitivity: 1})

    {:ok, _calibration} =
      Hardware.save_calibration(input.id, %{
        max_hardware_value: 1023,
        min_value: 0,
        max_value: 1000,
        has_rollover: false,
        is_inverted: false
      })

    device_conn = %DeviceConnection{
      port: "/dev/cu.selector#{System.unique_integer([:positive])}",
      status: :connected,
      device_config_id: device.config_id
    }

    Mimic.stub(Trenino.Serial.Connection, :list_devices, fn -> [device_conn] end)

    %{train: train, element: element, input: input, port: device_conn.port, pin: input.pin}
  end

  defp stub_simulator(:connected) do
    Mimic.stub(SimulatorConnection, :get_status, fn ->
      %ConnectionState{status: :connected, client: @client}
    end)
  end

  defp stub_simulator(:disconnected) do
    Mimic.stub(SimulatorConnection, :get_status, fn -> ConnectionState.new() end)
  end

  defp connected_status, do: %ConnectionState{status: :connected, client: @client}

  defp start_controller do
    {:ok, controller} = start_supervised(SelectorController)
    Sandbox.allow(Trenino.Repo, self(), controller)
    controller
  end

  # Positions: enter sets the headlights to the position index. Overrides are
  # merged per index.
  defp configure(%{element: element, input: input}, overrides \\ %{}, attrs \\ %{}) do
    positions =
      3
      |> SelectorMapper.even_split()
      |> Enum.map(fn range ->
        range
        |> Map.merge(%{
          label: "P#{range.index}",
          enter_kind: :set_value,
          enter_endpoint: @endpoint,
          enter_value: range.index * 1.0
        })
        |> Map.merge(Map.get(overrides, range.index, %{}))
      end)

    {:ok, binding} =
      TrainContext.save_selector(
        element.id,
        Map.merge(%{input_id: input.id, positions: positions}, attrs)
      )

    binding
  end

  # Starts the controller with the train active, flushing the sync so tests
  # start from a known position-less state.
  defp activate(controller, train) do
    send(controller, {:train_changed, train})
    SelectorController.get_state()
  end

  defp read(controller, ctx, raw) do
    send(controller, {:input_value_updated, ctx.port, ctx.pin, raw})
    SelectorController.get_state()
  end

  describe "position changes" do
    setup ctx do
      configure(ctx, %{0 => %{exit_kind: :keystroke, exit_keystroke: "X"}})
      controller = start_controller()
      activate(controller, ctx.train)
      %{controller: controller}
    end

    test "fires the enter action of the first position reached", ctx do
      state = read(ctx.controller, ctx, @pos1)

      assert_receive {:set, @endpoint, 1.0}
      assert %{index: 1} = state.current[ctx.element.id]
    end

    test "runs the exit action before the enter action", ctx do
      read(ctx.controller, ctx, @pos0)
      assert_receive {:set, @endpoint, +0.0}

      read(ctx.controller, ctx, @pos1)

      # assert_receive with an unbound pattern takes the oldest match, so the
      # two receives below check the order the actions ran in.
      assert_receive message
      assert message == {:tap, "X"}
      assert_receive message
      assert message == {:set, @endpoint, 1.0}
    end

    test "does not re-fire on jitter within a position", ctx do
      read(ctx.controller, ctx, @pos1)
      assert_receive {:set, @endpoint, 1.0}

      read(ctx.controller, ctx, @pos1 + 5)
      read(ctx.controller, ctx, @pos1 - 5)

      refute_receive {:set, _, _}, 100
    end

    test "ignores readings in a dead zone and keeps the last position", ctx do
      read(ctx.controller, ctx, @pos0)
      assert_receive {:set, @endpoint, +0.0}

      state = read(ctx.controller, ctx, @gap)
      refute_receive {:set, _, _}, 100
      assert %{index: 0} = state.current[ctx.element.id]

      # Back into the same position from the gap: still nothing
      read(ctx.controller, ctx, @pos0)
      refute_receive {:tap, _}, 100
      refute_receive {:set, _, _}, 50
    end

    test "fires nothing for a reading in a dead zone before any position", ctx do
      state = read(ctx.controller, ctx, @gap)

      refute_receive {:set, _, _}, 100
      assert state.current == %{}
    end

    test "ignores readings from unbound inputs", ctx do
      send(ctx.controller, {:input_value_updated, ctx.port, ctx.pin + 1, @pos1})
      send(ctx.controller, {:input_value_updated, "/dev/other", ctx.pin, @pos1})
      SelectorController.get_state()

      refute_receive {:set, _, _}, 100
    end

    test "broadcasts the new position", ctx do
      SelectorController.subscribe()
      element_id = ctx.element.id

      read(ctx.controller, ctx, @pos2)

      assert_receive {:selector_position_changed, ^element_id, %{index: 2, label: "P2"}}
    end

    test "clears state when the train deactivates", ctx do
      read(ctx.controller, ctx, @pos1)
      assert_receive {:set, @endpoint, 1.0}

      send(ctx.controller, {:train_changed, nil})
      state = read(ctx.controller, ctx, @pos2)

      assert state.active_train == nil
      assert state.current == %{}
      refute_receive {:set, _, _}, 100
    end
  end

  describe "sequences" do
    setup %{train: train} = ctx do
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Slow"})

      {:ok, _} =
        TrainContext.set_sequence_commands(sequence, [
          %{endpoint: "A.InputValue", value: 1.0, delay_ms: 300},
          %{endpoint: "B.InputValue", value: 1.0, delay_ms: 0}
        ])

      configure(ctx, %{1 => %{enter_kind: :sequence, enter_sequence_id: sequence.id}})
      controller = start_controller()
      activate(controller, ctx.train)
      %{controller: controller}
    end

    test "runs a sequence enter action", ctx do
      read(ctx.controller, ctx, @pos1)

      assert_receive {:set, "A.InputValue", 1.0}
      assert_receive {:set, "B.InputValue", 1.0}, 1_000
    end

    test "a new transition cancels the running sequence", ctx do
      read(ctx.controller, ctx, @pos1)
      assert_receive {:set, "A.InputValue", 1.0}

      read(ctx.controller, ctx, @pos2)
      assert_receive {:set, @endpoint, 2.0}

      refute_receive {:set, "B.InputValue", _}, 500
    end
  end

  describe "sync" do
    test "fires the current position's enter action when the train activates", ctx do
      configure(ctx, %{0 => %{exit_kind: :keystroke, exit_keystroke: "X"}})
      port = ctx.port
      pin = ctx.pin
      Mimic.stub(ConfigurationManager, :get_input_values, fn ^port -> %{pin => @pos2} end)

      controller = start_controller()
      state = activate(controller, ctx.train)

      assert_receive {:set, @endpoint, 2.0}
      refute_receive {:tap, _}, 100
      assert %{index: 2} = state.current[ctx.element.id]
    end

    test "waits for a live reading when none is cached", ctx do
      configure(ctx)
      controller = start_controller()

      state = activate(controller, ctx.train)
      refute_receive {:set, _, _}, 100
      assert state.current == %{}

      read(controller, ctx, @pos1)
      assert_receive {:set, @endpoint, 1.0}
    end

    test "does not fire for a cached reading in a dead zone", ctx do
      configure(ctx)
      pin = ctx.pin
      Mimic.stub(ConfigurationManager, :get_input_values, fn _port -> %{pin => @gap} end)

      controller = start_controller()
      state = activate(controller, ctx.train)

      refute_receive {:set, _, _}, 100
      assert state.current == %{}
    end

    test "waits for the simulator, then syncs once on connect", ctx do
      configure(ctx)
      pin = ctx.pin
      Mimic.stub(ConfigurationManager, :get_input_values, fn _port -> %{pin => @pos1} end)
      stub_simulator(:disconnected)

      controller = start_controller()
      activate(controller, ctx.train)
      refute_receive {:set, _, _}, 100

      stub_simulator(:connected)
      send(controller, {:simulator_status_changed, connected_status()})
      SelectorController.get_state()
      assert_receive {:set, @endpoint, 1.0}

      # A repeated :connected broadcast does not re-sync
      send(controller, {:simulator_status_changed, connected_status()})
      SelectorController.get_state()
      refute_receive {:set, _, _}, 100
    end

    test "re-syncs after the simulator reconnects", ctx do
      configure(ctx)
      pin = ctx.pin
      Mimic.stub(ConfigurationManager, :get_input_values, fn _port -> %{pin => @pos1} end)

      controller = start_controller()
      activate(controller, ctx.train)
      assert_receive {:set, @endpoint, 1.0}

      send(controller, {:simulator_status_changed, ConnectionState.new()})
      send(controller, {:simulator_status_changed, connected_status()})
      SelectorController.get_state()

      assert_receive {:set, @endpoint, 1.0}
    end

    test "a reload keeps the position of an unchanged selector", ctx do
      configure(ctx)
      pin = ctx.pin
      Mimic.stub(ConfigurationManager, :get_input_values, fn _port -> %{pin => @pos2} end)

      controller = start_controller()
      activate(controller, ctx.train)
      assert_receive {:set, @endpoint, 2.0}

      SelectorController.reload_bindings()
      state = SelectorController.get_state()

      refute_receive {:set, _, _}, 100
      assert %{index: 2} = state.current[ctx.element.id]
    end

    test "a reload re-syncs a selector whose positions changed", ctx do
      configure(ctx)
      pin = ctx.pin
      Mimic.stub(ConfigurationManager, :get_input_values, fn _port -> %{pin => @pos2} end)

      controller = start_controller()
      activate(controller, ctx.train)
      assert_receive {:set, @endpoint, 2.0}

      # save_selector reloads the controller itself
      configure(ctx, %{2 => %{enter_value: 5.0}})
      SelectorController.get_state()

      assert_receive {:set, @endpoint, 5.0}
    end

    test "a reload applies edited sequence commands", %{train: train} = ctx do
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Lights"})
      {:ok, _} = TrainContext.set_sequence_commands(sequence, [%{endpoint: "Z", value: 1.0}])

      configure(ctx, %{1 => %{enter_kind: :sequence, enter_sequence_id: sequence.id}})
      controller = start_controller()
      activate(controller, ctx.train)

      {:ok, _} = TrainContext.set_sequence_commands(sequence, [%{endpoint: "Y", value: 2.0}])
      SelectorController.get_state()

      read(controller, ctx, @pos1)
      assert_receive {:set, "Y", 2.0}
      refute_received {:set, "Z", _}
    end

    test "a deleted sequence no longer runs", %{train: train} = ctx do
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Lights"})
      {:ok, _} = TrainContext.set_sequence_commands(sequence, [%{endpoint: "Z", value: 1.0}])

      configure(ctx, %{1 => %{enter_kind: :sequence, enter_sequence_id: sequence.id}})
      controller = start_controller()
      activate(controller, ctx.train)

      {:ok, _} = TrainContext.delete_sequence(sequence)
      SelectorController.get_state()

      state = read(controller, ctx, @pos1)
      refute_receive {:set, "Z", _}, 100
      assert %{index: 1} = state.current[ctx.element.id]
    end

    test "a deleted binding stops the selector and clears its position", ctx do
      configure(ctx)
      controller = start_controller()
      activate(controller, ctx.train)
      read(controller, ctx, @pos1)
      assert_receive {:set, @endpoint, 1.0}

      SelectorController.subscribe()
      element_id = ctx.element.id
      :ok = TrainContext.delete_selector_binding(element_id)
      SelectorController.get_state()

      assert_receive {:selector_position_changed, ^element_id, nil}
      read(controller, ctx, @pos2)
      refute_receive {:set, _, _}, 100
    end

    test "deleting the element stops the selector", ctx do
      configure(ctx)
      controller = start_controller()
      activate(controller, ctx.train)

      {:ok, _} = TrainContext.delete_element(ctx.element)
      state = SelectorController.get_state()

      assert state.binding_lookup == %{}
    end

    test "a sync keeps the known position when the knob rests in a dead zone", ctx do
      configure(ctx)
      pin = ctx.pin
      controller = start_controller()
      activate(controller, ctx.train)
      read(controller, ctx, @pos1)
      assert_receive {:set, @endpoint, 1.0}

      Mimic.stub(ConfigurationManager, :get_input_values, fn _port -> %{pin => @gap} end)
      send(controller, {:simulator_status_changed, ConnectionState.new()})
      send(controller, {:simulator_status_changed, connected_status()})
      state = SelectorController.get_state()

      assert_receive {:set, @endpoint, 1.0}
      assert %{index: 1} = state.current[ctx.element.id]
    end

    test "a sync does not tap keystrokes", ctx do
      configure(ctx, %{1 => %{enter_kind: :keystroke, enter_keystroke: "L"}})
      pin = ctx.pin
      Mimic.stub(ConfigurationManager, :get_input_values, fn _port -> %{pin => @pos1} end)

      controller = start_controller()
      state = activate(controller, ctx.train)

      refute_receive {:tap, _}, 100
      assert %{index: 1} = state.current[ctx.element.id]

      # A live move still taps
      read(controller, ctx, @pos2)
      read(controller, ctx, @pos1)
      assert_receive {:tap, "L"}
    end

    test "survives ConfigurationManager not answering", ctx do
      configure(ctx)

      Mimic.stub(ConfigurationManager, :get_input_values, fn _port ->
        exit({:timeout, {GenServer, :call, []}})
      end)

      controller = start_controller()
      state = activate(controller, ctx.train)

      assert Process.alive?(controller)
      assert state.current == %{}
    end

    test "syncs selectors without a position when a device connects", ctx do
      configure(ctx)
      controller = start_controller()
      activate(controller, ctx.train)

      pin = ctx.pin
      Mimic.stub(ConfigurationManager, :get_input_values, fn _port -> %{pin => @pos0} end)
      send(controller, {:devices_updated, []})
      state = SelectorController.get_state()

      assert_receive {:set, @endpoint, +0.0}
      assert %{index: 0} = state.current[ctx.element.id]

      # Already positioned: another device update does not re-fire
      send(controller, {:devices_updated, []})
      SelectorController.get_state()
      refute_receive {:set, _, _}, 100
    end
  end

  describe "bindings" do
    test "ignores a disabled binding", ctx do
      configure(ctx, %{}, %{enabled: false})
      controller = start_controller()
      state = activate(controller, ctx.train)

      assert state.binding_lookup == %{}
      read(controller, ctx, @pos1)
      refute_receive {:set, _, _}, 100
    end

    test "loads bindings of an already active train on start", ctx do
      configure(ctx)
      train = ctx.train

      :sys.replace_state(Process.whereis(Detection), fn state ->
        %{state | active_train: train}
      end)

      pin = ctx.pin
      Mimic.stub(ConfigurationManager, :get_input_values, fn _port -> %{pin => @pos1} end)

      start_controller()
      state = SelectorController.get_state()

      assert Map.has_key?(state.binding_lookup, ctx.input.id)
      assert_receive {:set, @endpoint, 1.0}
    end

    test "subscribes to each port once across device reconnects", ctx do
      test_pid = self()

      Mimic.stub(ConfigurationManager, :subscribe_input_values, fn port ->
        send(test_pid, {:subscribed, port})
        :ok
      end)

      configure(ctx)
      controller = start_controller()
      port = ctx.port
      assert_receive {:subscribed, ^port}

      Mimic.stub(Trenino.Serial.Connection, :list_devices, fn -> [] end)
      send(controller, {:devices_updated, []})
      SelectorController.get_state()

      device_conn = %DeviceConnection{
        port: port,
        status: :connected,
        device_config_id: Repo.get!(Trenino.Hardware.Device, ctx.input.device_id).config_id
      }

      Mimic.stub(Trenino.Serial.Connection, :list_devices, fn -> [device_conn] end)
      send(controller, {:devices_updated, [device_conn]})
      SelectorController.get_state()

      refute_received {:subscribed, ^port}
    end

    test "skips inputs without calibration", ctx do
      configure(ctx)
      Repo.delete_all(Trenino.Hardware.Input.Calibration)

      controller = start_controller()
      activate(controller, ctx.train)
      read(controller, ctx, @pos1)

      refute_receive {:set, _, _}, 100
    end

    test "a position without actions only updates the current position", ctx do
      configure(ctx, %{1 => %{enter_kind: :none}})
      controller = start_controller()
      activate(controller, ctx.train)

      state = read(controller, ctx, @pos1)

      refute_receive {:set, _, _}, 100
      assert %{index: 1} = state.current[ctx.element.id]
    end
  end

  describe "simulator connection" do
    setup ctx do
      configure(ctx, %{0 => %{exit_kind: :keystroke, exit_keystroke: "X"}})
      %{controller: start_controller()}
    end

    test "tracks positions but runs no actions while disconnected", ctx do
      stub_simulator(:disconnected)
      send(ctx.controller, {:simulator_status_changed, ConnectionState.new()})
      activate(ctx.controller, ctx.train)
      SelectorController.subscribe()
      element_id = ctx.element.id

      read(ctx.controller, ctx, @pos0)
      state = read(ctx.controller, ctx, @pos1)

      assert_receive {:selector_position_changed, ^element_id, %{index: 1}}
      refute_receive {:tap, _}, 100
      refute_received {:set, _, _}
      assert %{index: 1} = state.current[element_id]
    end

    test "stops running actions when the simulator disconnects", %{train: train} = ctx do
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Slow"})

      {:ok, _} =
        TrainContext.set_sequence_commands(sequence, [
          %{endpoint: "A", value: 1.0, delay_ms: 2_000},
          %{endpoint: "B", value: 1.0}
        ])

      configure(ctx, %{1 => %{enter_kind: :sequence, enter_sequence_id: sequence.id}})
      SelectorController.reload_bindings()
      activate(ctx.controller, ctx.train)

      read(ctx.controller, ctx, @pos1)
      assert_receive {:set, "A", 1.0}

      send(ctx.controller, {:simulator_status_changed, ConnectionState.new()})
      state = SelectorController.get_state()

      assert state.runners == %{}
    end
  end

  describe "get_position/1" do
    test "returns :none when the controller is not running", ctx do
      assert SelectorController.get_position(ctx.element.id) == :none
    end

    test "returns the current position and clears it on train change", ctx do
      configure(ctx)
      controller = start_controller()
      activate(controller, ctx.train)

      assert SelectorController.get_position(ctx.element.id) == :none

      read(controller, ctx, @pos2)
      assert SelectorController.get_position(ctx.element.id) == {:ok, %{index: 2, label: "P2"}}

      SelectorController.subscribe()
      element_id = ctx.element.id
      send(controller, {:train_changed, nil})
      SelectorController.get_state()

      assert_receive {:selector_position_changed, ^element_id, nil}
      assert SelectorController.get_position(element_id) == :none
    end
  end

  describe "runners" do
    test "an exit sequence finishes before the enter action", %{train: train} = ctx do
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Off"})

      {:ok, _} =
        TrainContext.set_sequence_commands(sequence, [
          %{endpoint: "Off1", value: 1.0, delay_ms: 50},
          %{endpoint: "Off2", value: 1.0}
        ])

      configure(ctx, %{0 => %{exit_kind: :sequence, exit_sequence_id: sequence.id}})
      controller = start_controller()
      activate(controller, ctx.train)
      read(controller, ctx, @pos0)
      assert_receive {:set, @endpoint, +0.0}

      read(controller, ctx, @pos1)

      for expected <- [{:set, "Off1", 1.0}, {:set, "Off2", 1.0}, {:set, @endpoint, 1.0}] do
        assert_receive message, 1_000
        assert message == expected
      end
    end

    test "recovers after a runner crashes", ctx do
      configure(ctx, %{1 => %{enter_kind: :keystroke, enter_keystroke: "L"}})
      Mimic.stub(Keyboard, :tap, fn _ -> raise "boom" end)

      controller = start_controller()
      activate(controller, ctx.train)
      %{runners: %{} = runners} = read(controller, ctx, @pos1)
      %Task{pid: pid} = Map.fetch!(runners, ctx.element.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}

      # The controller handled the same :DOWN and dropped the runner
      assert SelectorController.get_state().runners == %{}

      read(controller, ctx, @pos2)
      assert_receive {:set, @endpoint, 2.0}
    end

    test "a train change kills running actions", %{train: train} = ctx do
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Slow"})

      {:ok, _} =
        TrainContext.set_sequence_commands(sequence, [
          %{endpoint: "A", value: 1.0, delay_ms: 300},
          %{endpoint: "B", value: 1.0}
        ])

      configure(ctx, %{1 => %{enter_kind: :sequence, enter_sequence_id: sequence.id}})
      controller = start_controller()
      activate(controller, ctx.train)
      read(controller, ctx, @pos1)
      assert_receive {:set, "A", 1.0}

      {:ok, other} =
        TrainContext.create_train(%{name: "Other", identifiers: [%{identifier: "other_rt"}]})

      state = activate(controller, other)

      assert state.runners == %{}
      refute_receive {:set, "B", _}, 500
    end
  end
end
