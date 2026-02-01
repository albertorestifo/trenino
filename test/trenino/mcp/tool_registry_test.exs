defmodule Trenino.MCP.ToolRegistryTest do
  use Trenino.DataCase, async: false

  alias Trenino.MCP.ToolRegistry

  describe "list_tools/0" do
    test "returns all 20 tools" do
      tools = ToolRegistry.list_tools()
      assert length(tools) == 20
    end

    test "all tools have required fields" do
      for tool <- ToolRegistry.list_tools() do
        assert Map.has_key?(tool, :name)
        assert Map.has_key?(tool, :description)
        assert Map.has_key?(tool, :input_schema)
        assert is_binary(tool.name)
        assert is_binary(tool.description)
        assert is_map(tool.input_schema)
      end
    end

    test "tool names are unique" do
      names = ToolRegistry.list_tools() |> Enum.map(& &1.name)
      assert length(names) == length(Enum.uniq(names))
    end
  end

  describe "call_tool/2" do
    test "dispatches to the correct tool module" do
      assert {:ok, %{trains: []}} = ToolRegistry.call_tool("list_trains", %{})
    end

    test "returns error for unknown tool" do
      assert {:error, "Unknown tool: fake_tool"} = ToolRegistry.call_tool("fake_tool", %{})
    end
  end
end
