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

  test "apply requires explicit acknowledgement only with a 0x70 display" do
    {:ok, device} = Hardware.create_device(%{name: "Gauge"})
    {:ok, _} = Hardware.create_stepper_axis(device.id, %{"name" => "Speed"})

    refute Hardware.registration_ack_required?(device.id)

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

    assert Hardware.registration_ack_required?(device.id)

    assert {:error, "registration acknowledgement required"} =
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
end
