defmodule Trenino.MCP.ServerTest do
  use Trenino.DataCase, async: false

  alias Trenino.MCP.Server

  describe "handle_message/1" do
    test "initialize returns server info and capabilities" do
      message = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{}
      }

      assert {:reply, response} = Server.handle_message(message)
      assert response.jsonrpc == "2.0"
      assert response.id == 1
      assert response.result.serverInfo.name == "Trenino"
      assert response.result.capabilities.tools == %{}
      assert is_binary(response.result.protocolVersion)
    end

    test "notifications/initialized returns ok" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized",
        "params" => %{}
      }

      assert {:reply, response} = Server.handle_message(message)
      assert response.result == nil
    end

    test "tools/list returns tool definitions" do
      message = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/list",
        "params" => %{}
      }

      assert {:reply, response} = Server.handle_message(message)
      assert %{tools: tools} = response.result
      assert is_list(tools)
      assert length(tools) == 23

      tool_names = Enum.map(tools, & &1.name)
      assert "list_trains" in tool_names
      assert "create_output_binding" in tool_names
      assert "list_simulator_endpoints" in tool_names
      assert "create_button_binding" in tool_names
      assert "create_sequence" in tool_names
      assert "list_devices" in tool_names
    end

    test "tools/list tool definitions have required fields" do
      message = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/list",
        "params" => %{}
      }

      {:reply, response} = Server.handle_message(message)

      for tool <- response.result.tools do
        assert is_binary(tool.name)
        assert is_binary(tool.description)
        assert is_map(tool.inputSchema)
      end
    end

    test "ping returns empty result" do
      message = %{"jsonrpc" => "2.0", "id" => 3, "method" => "ping", "params" => %{}}

      assert {:reply, response} = Server.handle_message(message)
      assert response.result == %{}
    end

    test "unknown method returns error" do
      message = %{"jsonrpc" => "2.0", "id" => 4, "method" => "unknown/method", "params" => %{}}

      assert {:error, response} = Server.handle_message(message)
      assert response.error.code == -32_601
      assert response.error.message =~ "Method not found"
    end

    test "invalid request returns error" do
      assert {:error, response} = Server.handle_message(%{"invalid" => true})
      assert response.error.code == -32_600
    end

    test "tools/call with missing params returns error" do
      message = %{
        "jsonrpc" => "2.0",
        "id" => 5,
        "method" => "tools/call",
        "params" => %{}
      }

      assert {:error, response} = Server.handle_message(message)
      assert response.error.code == -32_602
    end

    test "tools/call dispatches to tool and returns content" do
      message = %{
        "jsonrpc" => "2.0",
        "id" => 6,
        "method" => "tools/call",
        "params" => %{
          "name" => "list_trains",
          "arguments" => %{}
        }
      }

      assert {:reply, response} = Server.handle_message(message)
      assert [%{type: "text", text: text}] = response.result.content
      assert %{"trains" => []} = Jason.decode!(text)
    end

    test "tools/call with unknown tool returns error content" do
      message = %{
        "jsonrpc" => "2.0",
        "id" => 7,
        "method" => "tools/call",
        "params" => %{
          "name" => "nonexistent_tool",
          "arguments" => %{}
        }
      }

      assert {:reply, response} = Server.handle_message(message)
      assert response.result.isError == true
      assert [%{type: "text", text: text}] = response.result.content
      assert text =~ "Unknown tool"
    end
  end
end
