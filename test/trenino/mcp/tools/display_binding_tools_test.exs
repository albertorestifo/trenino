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
end
