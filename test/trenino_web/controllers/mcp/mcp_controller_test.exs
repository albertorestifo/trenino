defmodule TreninoWeb.MCP.MCPControllerTest do
  use TreninoWeb.ConnCase, async: false

  describe "POST /mcp/messages" do
    test "returns 400 when session_id is missing", %{conn: conn} do
      conn = post(conn, "/mcp/messages", %{"jsonrpc" => "2.0", "method" => "ping", "id" => 1})
      assert json_response(conn, 400)["error"] =~ "session_id"
    end

    test "returns 404 when session is not found", %{conn: conn} do
      conn =
        post(conn, "/mcp/messages?session_id=nonexistent", %{
          "jsonrpc" => "2.0",
          "method" => "ping",
          "id" => 1
        })

      assert json_response(conn, 404)["error"] =~ "Session not found"
    end

    test "processes message and returns 202 for valid session", %{conn: conn} do
      session_id = "test-session-#{System.unique_integer([:positive])}"
      {:ok, _} = Registry.register(Trenino.MCP.SessionRegistry, session_id, self())

      conn =
        post(conn, "/mcp/messages?session_id=#{session_id}", %{
          "jsonrpc" => "2.0",
          "method" => "ping",
          "id" => 1
        })

      assert response(conn, 202)

      # The response should have been sent to us via message
      assert_receive {:mcp_response, response}
      assert response.jsonrpc == "2.0"
      assert response.id == 1
      assert response.result == %{}
    end

    test "handles tools/list via POST", %{conn: conn} do
      session_id = "test-session-#{System.unique_integer([:positive])}"
      {:ok, _} = Registry.register(Trenino.MCP.SessionRegistry, session_id, self())

      conn =
        post(conn, "/mcp/messages?session_id=#{session_id}", %{
          "jsonrpc" => "2.0",
          "method" => "tools/list",
          "id" => 2,
          "params" => %{}
        })

      assert response(conn, 202)

      assert_receive {:mcp_response, response}
      assert %{tools: tools} = response.result
      assert length(tools) == 23
    end

    test "handles tools/call via POST", %{conn: conn} do
      session_id = "test-session-#{System.unique_integer([:positive])}"
      {:ok, _} = Registry.register(Trenino.MCP.SessionRegistry, session_id, self())

      conn =
        post(conn, "/mcp/messages?session_id=#{session_id}", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "id" => 3,
          "params" => %{
            "name" => "list_trains",
            "arguments" => %{}
          }
        })

      assert response(conn, 202)

      assert_receive {:mcp_response, response}
      assert [%{type: "text", text: text}] = response.result.content
      assert %{"trains" => []} = Jason.decode!(text)
    end

    test "handles error responses via POST", %{conn: conn} do
      session_id = "test-session-#{System.unique_integer([:positive])}"
      {:ok, _} = Registry.register(Trenino.MCP.SessionRegistry, session_id, self())

      conn =
        post(conn, "/mcp/messages?session_id=#{session_id}", %{
          "jsonrpc" => "2.0",
          "method" => "unknown/method",
          "id" => 4,
          "params" => %{}
        })

      assert response(conn, 202)

      assert_receive {:mcp_response, response}
      assert response.error.code == -32_601
    end
  end
end
