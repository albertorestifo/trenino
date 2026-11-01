defmodule TreninoWeb.DisplayBindingWizardTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Train, as: TrainContext

  setup do
    {:ok, train} =
      TrainContext.create_train(%{
        name: "Wizard Train",
        identifiers: [%{identifier: "Wizard_Train_#{System.unique_integer([:positive])}"}]
      })

    {:ok, device} = Hardware.create_device(%{name: "Input Only Panel"})
    %{train: train, device: device}
  end

  defp render_wizard(train) do
    render_component(TreninoWeb.DisplayBindingWizard,
      id: "display-binding-wizard",
      train_id: train.id,
      client: nil,
      binding: nil
    )
  end

  test "display wizard does not list an MCP23017", %{train: train, device: device} do
    {:ok, _} =
      Hardware.create_i2c_module(device.id, %{
        name: "Switch bank",
        module_chip: :mcp23017,
        i2c_address: 0x20,
        params: %{direct_mask: 1, row_mask: 0, col_mask: 0}
      })

    html = render_wizard(train)

    refute html =~ "Switch bank"
    assert html =~ "Add a display to a hardware configuration first."
  end

  test "display wizard lists a seven segment display", %{train: train, device: device} do
    {:ok, _} =
      Hardware.create_i2c_module(device.id, %{
        name: "Speed display",
        module_chip: :ht16k33,
        i2c_address: 0x70,
        params: %{display_type: :seven_segment, num_digits: 4}
      })

    assert render_wizard(train) =~ "Speed display"
  end
end
