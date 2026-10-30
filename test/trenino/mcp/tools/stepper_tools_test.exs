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
end
