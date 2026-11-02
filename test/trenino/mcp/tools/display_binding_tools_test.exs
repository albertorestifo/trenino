defmodule Trenino.MCP.Tools.DisplayBindingToolsTest do
  use Trenino.DataCase, async: true
  alias Trenino.MCP.Tools.DisplayBindingTools

  test "tools/0 returns 4 tools" do
    assert length(DisplayBindingTools.tools()) == 4
  end

  test "list_display_bindings returns empty list for unknown train" do
    assert {:ok, %{display_bindings: []}} =
             DisplayBindingTools.execute("list_display_bindings", %{"train_id" => 0})
  end

  test "display binding tool rejects an input chip" do
    {:ok, train} =
      Trenino.Train.create_train(%{
        name: "T",
        identifiers: [%{identifier: "DBT_#{System.unique_integer([:positive])}"}]
      })

    {:ok, device} = Trenino.Hardware.create_device(%{name: "Dev"})

    {:ok, mcp} =
      Trenino.Hardware.create_i2c_module(device.id, %{
        module_chip: :mcp23017,
        i2c_address: 0x20,
        params: %{direct_mask: 1, row_mask: 0, col_mask: 0}
      })

    assert {:error, message} =
             DisplayBindingTools.execute("create_display_binding", %{
               "train_id" => train.id,
               "i2c_module_id" => mcp.id,
               "endpoint" => "CurrentDrivableActor/Function.Speed",
               "format_string" => "{value}"
             })

    assert inspect(message) =~ "must be a display module"
    assert Trenino.Train.list_display_bindings(train.id) == []

    {:ok, display} =
      Trenino.Hardware.create_i2c_module(device.id, %{
        module_chip: :ht16k33,
        i2c_address: 0x70,
        params: %{display_type: :seven_segment, num_digits: 4}
      })

    {:ok, binding} =
      Trenino.Train.create_display_binding(train.id, %{
        i2c_module_id: display.id,
        endpoint: "CurrentDrivableActor/Function.Speed",
        format_string: "{value}"
      })

    assert {:error, cs} = Trenino.Train.update_display_binding(binding, %{i2c_module_id: mcp.id})
    assert %{i2c_module_id: ["must be a display module"]} = errors_on(cs)
  end
end
