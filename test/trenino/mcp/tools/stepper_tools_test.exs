defmodule Trenino.MCP.Tools.StepperToolsTest do
  use Trenino.DataCase, async: true
  alias Trenino.Hardware
  alias Trenino.MCP.Tools.StepperTools

  test "CRUD uses domain validation and never implicitly references" do
    {:ok, device} = Hardware.create_device(%{name: "Gauge"})

    assert {:ok, %{axis: axis}} =
             StepperTools.execute("create_stepper_axis", %{
               "device_id" => device.id,
               "name" => "Speed"
             })

    refute axis.commissioned
    assert axis.startup_reference == :manual

    assert {:ok, %{axes: [_]}} =
             StepperTools.execute("list_stepper_axes", %{"device_id" => device.id})

    assert {:error, _} =
             StepperTools.execute("update_stepper_axis", %{"id" => axis.id, "max_speed" => 201})

    assert {:error, _} =
             StepperTools.execute("control_stepper_axis", %{
               "id" => axis.id,
               "operation" => "home"
             })

    assert {:error, _} = StepperTools.execute("create_stepper_axis", %{})
  end

  test "apply is never blocked by a 0x70 display and warns instead" do
    {:ok, device} = Hardware.create_device(%{name: "Gauge"})
    {:ok, _} = Hardware.create_stepper_axis(device.id, %{"name" => "Speed"})

    refute Hardware.allcall_conflict_possible?(device.id)
    assert Hardware.allcall_warning(device.id) == nil

    assert {:error, "device not connected"} =
             StepperTools.execute("apply_stepper_configuration", %{"device_id" => device.id})

    {:ok, _} =
      Hardware.create_i2c_module(device.id, %{
        name: "D",
        module_chip: :ht16k33,
        i2c_address: 0x70,
        params: %{
          brightness: 8,
          num_digits: 4,
          display_type: :fourteen_segment,
          has_dot: false,
          align_right: true,
          min_value: 0.0,
          max_value: 9999.0
        }
      })

    assert Hardware.allcall_conflict_possible?(device.id)
    assert Hardware.allcall_warning(device.id) =~ "unplug the 0x70 display"

    assert {:error, "device not connected"} =
             StepperTools.execute("apply_stepper_configuration", %{"device_id" => device.id})
  end

  test "update reports next steps" do
    {:ok, device} = Hardware.create_device(%{name: "Gauge"})

    {:ok, %{axis: axis}} =
      StepperTools.execute("create_stepper_axis", %{"device_id" => device.id, "name" => "S"})

    assert {:ok, %{axis: %{reverse: true}, next_steps: steps}} =
             StepperTools.execute("update_stepper_axis", %{"id" => axis.id, "reverse" => true})

    assert steps =~ "apply_stepper_configuration"
  end

  test "attrs can never set commissioned (create or update)" do
    {:ok, device} = Hardware.create_device(%{name: "Gauge"})

    assert {:ok, %{axis: axis}} =
             StepperTools.execute("create_stepper_axis", %{
               "device_id" => device.id,
               "name" => "Speed",
               "commissioned" => true
             })

    refute axis.commissioned

    StepperTools.execute("update_stepper_axis", %{"id" => axis.id, "commissioned" => true})
    assert {:ok, reloaded} = Hardware.get_stepper_axis(axis.id)
    refute reloaded.commissioned
  end

  test "invalid enum and integer options come back as errors instead of crashing" do
    {:ok, device} = Hardware.create_device(%{name: "Gauge"})

    {:ok, %{axis: axis}} =
      StepperTools.execute("create_stepper_axis", %{"device_id" => device.id, "name" => "Speed"})

    for args <- [%{"mode" => "bogus"}, %{"home_direction" => 5}, %{"driver" => "nope"}] do
      assert {:error, text} =
               StepperTools.execute("update_stepper_axis", Map.put(args, "id", axis.id))

      assert is_binary(text)
    end

    # Through the real server dispatch, the client gets an isError reply, not a crash.
    assert {:reply, %{result: %{isError: true, content: [%{text: text}]}}} =
             Trenino.MCP.Server.handle_message(%{
               "jsonrpc" => "2.0",
               "id" => 1,
               "method" => "tools/call",
               "params" => %{
                 "name" => "update_stepper_axis",
                 "arguments" => %{"id" => axis.id, "mode" => "bogus"}
               }
             })

    assert text =~ "mode"
  end

  test "tool schemas advertise only the inputs each tool accepts" do
    tools = Map.new(StepperTools.tools(), &{&1.name, &1})
    control = tools["control_stepper_axis"].input_schema.properties

    assert Map.has_key?(control, :acknowledged)
    assert Map.keys(tools["list_stepper_axes"].input_schema.properties) == [:device_id]
    refute Map.has_key?(tools["update_stepper_axis"].input_schema.properties, :operation)

    for {_, tool} <- tools do
      refute Map.has_key?(tool.input_schema.properties, :inserted_at)
      refute Map.has_key?(tool.input_schema.properties, :updated_at)
    end

    refute tools["control_stepper_axis"].description =~ "Mutations require unique operation_token"

    assert tools["control_stepper_axis"].description =~
             "except claim, renew, release_lease and resume"
  end
end
