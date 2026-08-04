defmodule Trenino.MCP.Tools.VirtualJoystickToolsTest do
  use Trenino.DataCase, async: false

  alias Trenino.MCP.Tools.VirtualJoystickTools
  alias Trenino.Train, as: TrainContext
  alias Trenino.VirtualJoystick

  defmodule WindowsPlatform do
    def windows?, do: true
  end

  defmodule NonWindowsPlatform do
    def windows?, do: false
  end

  defmodule OffContext do
    def get_configuration, do: %{enabled: false}
    def list_mappings, do: []
    def confirm_enabled(enabled), do: {:ok, %{enabled: enabled}}
  end

  defmodule AbsentConfigurator do
    def status, do: :device_missing

    def create do
      receive do
        :finish_create -> {:ok, :created}
      after
        500 -> {:error, :cancelled}
      end
    end

    def delete, do: {:ok, :deleted}
  end

  defmodule EmptySerial do
    def subscribe, do: :ok
    def list_devices, do: []
  end

  defmodule EmptyInputs do
    def subscribe_input_values(_port), do: :ok
    def get_input_values(_port), do: %{}
  end

  describe "tools/0" do
    test "publishes strict schemas without command or path parameters" do
      tools = Map.new(VirtualJoystickTools.tools(), &{&1.name, &1.input_schema})

      assert map_size(tools) == 10
      assert Map.has_key?(tools, "check_virtual_joystick_installation")
      refute Map.has_key?(tools, "repair_virtual_joystick")

      assert tools["map_virtual_joystick_axis"] == %{
               type: "object",
               properties: %{
                 input_id: %{type: "integer", description: "Hardware input ID"},
                 device_index: %{type: "integer", enum: [1], description: "Virtual device index"},
                 axis: %{
                   type: "string",
                   enum: ["x", "y", "z", "rx", "ry", "rz", "slider_1", "slider_2"],
                   description: "Virtual joystick axis"
                 },
                 inverted: %{type: "boolean", description: "Invert the axis direction"},
                 replace: %{
                   type: "boolean",
                   description: "Replace an existing simulator/API destination"
                 }
               },
               required: ["input_id", "axis"],
               additionalProperties: false
             }

      assert %{properties: button_properties, additionalProperties: false} =
               tools["map_virtual_joystick_button"]

      assert button_properties.button == %{type: "integer", minimum: 1, maximum: 32}
      assert button_properties.device_index.enum == [1]
      assert button_properties.input_id.type == "integer"
      assert button_properties.replace.type == "boolean"

      refute Enum.any?(tools, fn {_name, schema} ->
               properties = Map.get(schema, :properties, %{})
               Map.has_key?(properties, :path) or Map.has_key?(properties, :command)
             end)
    end
  end

  describe "mapping tools" do
    test "lists mappings and creates or updates an axis mapping" do
      input = analog_input_fixture()

      assert {:ok, %{status: "ok", mapping: axis_mapping}} =
               VirtualJoystickTools.execute("map_virtual_joystick_axis", %{
                 "input_id" => input.id,
                 "axis" => "rx",
                 "device_index" => 1,
                 "inverted" => true
               })

      assert axis_mapping.input_id == input.id
      assert axis_mapping.target_type == "axis"
      assert axis_mapping.axis == "rx"
      assert axis_mapping.inverted

      assert {:ok, %{status: "ok", mapping: updated}} =
               VirtualJoystickTools.execute("map_virtual_joystick_axis", %{
                 "input_id" => input.id,
                 "axis" => "slider_1"
               })

      assert updated.id == axis_mapping.id
      assert updated.axis == "slider_1"

      assert {:ok, %{status: "ok", mappings: [listed]}} =
               VirtualJoystickTools.execute("list_virtual_joystick_mappings", %{})

      assert listed.id == axis_mapping.id
    end

    test "creates a button mapping and reports validation errors structurally" do
      input = button_input_fixture()

      assert {:ok, %{status: "ok", mapping: mapping}} =
               VirtualJoystickTools.execute("map_virtual_joystick_button", %{
                 "input_id" => input.id,
                 "button" => 32
               })

      assert mapping.target_type == "button"
      assert mapping.button == 32

      analog = analog_input_fixture(%{pin: 3})

      assert {:ok, %{status: "error", reason: reason}} =
               VirtualJoystickTools.execute("map_virtual_joystick_button", %{
                 "input_id" => analog.id,
                 "button" => 1
               })

      assert reason.code == "validation_failed"
      assert reason.errors.target_type == ["must target an axis"]
    end

    test "requires explicit replacement for a simulator destination" do
      input = analog_input_fixture()
      {:ok, train} = TrainContext.create_train(%{name: "MCP", identifier: "mcp-exclusive"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Throttle.Min",
          max_endpoint: "Throttle.Max",
          value_endpoint: "Throttle.Value"
        })

      {:ok, _binding} = TrainContext.bind_input(config.id, input.id)

      args = %{"input_id" => input.id, "axis" => "x"}

      assert {:ok, %{status: "error", reason: %{code: "destination_conflict"}}} =
               VirtualJoystickTools.execute("map_virtual_joystick_axis", args)

      assert {:ok, %{status: "ok"}} =
               VirtualJoystickTools.execute(
                 "map_virtual_joystick_axis",
                 Map.put(args, "replace", true)
               )

      assert {:error, :not_found} = TrainContext.get_binding(config.id)
    end

    test "deletes a mapping and reports a missing mapping" do
      input = button_input_fixture()
      {:ok, mapping} = VirtualJoystick.put_mapping(input.id, %{target_type: :button, button: 2})

      assert {:ok, %{status: "ok", deleted: true, id: id}} =
               VirtualJoystickTools.execute("delete_virtual_joystick_mapping", %{
                 "id" => mapping.id
               })

      assert id == mapping.id

      assert {:ok, %{status: "error", reason: %{code: "not_found"}}} =
               VirtualJoystickTools.execute("delete_virtual_joystick_mapping", %{
                 "id" => mapping.id
               })
    end
  end

  describe "argument validation" do
    test "rejects missing, mistyped, out-of-range, and extra mapping arguments without raising" do
      cases = [
        {"map_virtual_joystick_axis", %{"axis" => "x"}},
        {"map_virtual_joystick_axis", %{"input_id" => "1", "axis" => "x"}},
        {"map_virtual_joystick_axis", %{"input_id" => 1, "axis" => "pov"}},
        {"map_virtual_joystick_axis", %{"input_id" => 1, "axis" => "x", "device_index" => 2}},
        {"map_virtual_joystick_axis", %{"input_id" => 1, "axis" => "x", "device_index" => 1.0}},
        {"map_virtual_joystick_axis", %{"input_id" => 1, "axis" => "x", "inverted" => 1}},
        {"map_virtual_joystick_axis", %{"input_id" => 1, "axis" => "x", "replace" => "true"}},
        {"map_virtual_joystick_axis", %{"input_id" => 1, "axis" => "x", "command" => "cmd"}},
        {"map_virtual_joystick_button", %{"button" => 1}},
        {"map_virtual_joystick_button", %{"input_id" => 1, "button" => 0}},
        {"map_virtual_joystick_button", %{"input_id" => 1, "button" => 33}},
        {"map_virtual_joystick_button", %{"input_id" => 1, "button" => 1.0}},
        {"map_virtual_joystick_button", %{"input_id" => 1, "button" => 1, "device_index" => 1.0}},
        {"map_virtual_joystick_button", %{"input_id" => 1, "button" => 1, "replace" => "false"}},
        {"map_virtual_joystick_button", %{"input_id" => 1, "button" => 1, "extra" => true}},
        {"delete_virtual_joystick_mapping", %{}},
        {"delete_virtual_joystick_mapping", %{"id" => "1"}},
        {"delete_virtual_joystick_mapping", %{"id" => 1, "extra" => true}}
      ]

      for {tool, arguments} <- cases do
        assert {:ok, %{status: "error", reason: %{code: "validation_failed"}}} =
                 VirtualJoystickTools.execute(tool, arguments)
      end
    end

    test "rejects arguments for every parameterless tool" do
      for tool <- ~w(
        get_virtual_joystick_status
        list_virtual_joystick_mappings
        enable_virtual_joystick
        disable_virtual_joystick
        retry_virtual_joystick
        cleanup_virtual_joystick
        check_virtual_joystick_installation
      ) do
        assert {:ok, %{status: "error", reason: %{code: "validation_failed"}}} =
                 VirtualJoystickTools.execute(tool, %{"extra" => true})
      end
    end
  end

  describe "runtime tools" do
    test "reports unsupported status and lifecycle commands structurally" do
      previous = Application.get_env(:trenino, :virtual_joystick_mcp_platform)
      Application.put_env(:trenino, :virtual_joystick_mcp_platform, NonWindowsPlatform)

      on_exit(fn ->
        if previous,
          do: Application.put_env(:trenino, :virtual_joystick_mcp_platform, previous),
          else: Application.delete_env(:trenino, :virtual_joystick_mcp_platform)
      end)

      assert {:ok, %{status: "unsupported", reason: nil}} =
               VirtualJoystickTools.execute("get_virtual_joystick_status", %{})

      for command <- ~w(
        enable_virtual_joystick
        disable_virtual_joystick
        retry_virtual_joystick
        cleanup_virtual_joystick
        check_virtual_joystick_installation
      ) do
        assert {:ok, %{status: "error", reason: %{code: "unsupported"}}} =
                 VirtualJoystickTools.execute(command, %{})
      end
    end

    test "reports a missing Manager on Windows as runtime unavailable" do
      previous = Application.get_env(:trenino, :virtual_joystick_mcp_platform)
      Application.put_env(:trenino, :virtual_joystick_mcp_platform, WindowsPlatform)

      on_exit(fn ->
        if previous,
          do: Application.put_env(:trenino, :virtual_joystick_mcp_platform, previous),
          else: Application.delete_env(:trenino, :virtual_joystick_mcp_platform)
      end)

      assert {:ok, %{status: "runtime_unavailable", reason: %{code: "manager_unavailable"}}} =
               VirtualJoystickTools.execute("get_virtual_joystick_status", %{})

      assert {:ok, %{status: "error", reason: %{code: "runtime_unavailable"}}} =
               VirtualJoystickTools.execute("enable_virtual_joystick", %{})
    end

    test "enable and disable return transition acceptance without waiting for completion" do
      {:ok, _manager} =
        start_supervised(
          {Trenino.VirtualJoystick.Manager,
           name: Trenino.VirtualJoystick.Manager,
           platform: WindowsPlatform,
           context: OffContext,
           configurator: AbsentConfigurator,
           serial: EmptySerial,
           inputs: EmptyInputs,
           task_supervisor: Trenino.TaskSupervisor}
        )

      assert {:ok, %{status: "accepted", reason: nil}} =
               VirtualJoystickTools.execute("disable_virtual_joystick", %{})

      assert {:ok, %{status: "accepted", reason: nil}} =
               VirtualJoystickTools.execute("enable_virtual_joystick", %{})

      assert VirtualJoystick.status() == :enabling
    end
  end
end
