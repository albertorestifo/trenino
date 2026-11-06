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
      assert state.current == %{ctx.element.id => 1}
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
      assert state.current == %{ctx.element.id => 0}

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
      assert state.current == %{ctx.element.id => 2}
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

    test "re-syncs when bindings reload", ctx do
      configure(ctx)
      pin = ctx.pin
      Mimic.stub(ConfigurationManager, :get_input_values, fn _port -> %{pin => @pos2} end)

      controller = start_controller()
      activate(controller, ctx.train)
      assert_receive {:set, @endpoint, 2.0}

      SelectorController.reload_bindings()
      SelectorController.get_state()

      assert_receive {:set, @endpoint, 2.0}
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
      assert state.current == %{ctx.element.id => 0}

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

      start_controller()
      state = SelectorController.get_state()

      assert Map.has_key?(state.binding_lookup, ctx.input.id)
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
      assert state.current == %{ctx.element.id => 1}
    end
  end
end
