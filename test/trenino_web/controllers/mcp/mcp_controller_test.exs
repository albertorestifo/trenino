defmodule TreninoWeb.MCP.MCPControllerTest do
  use TreninoWeb.ConnCase, async: false

  setup %{conn: conn}, do: %{conn: %{conn | host: "localhost"}}

  describe "host and origin protection" do
    setup %{conn: conn} do
      session_id = "guard-#{System.unique_integer([:positive])}"
      {:ok, _} = Registry.register(Trenino.MCP.SessionRegistry, session_id, self())
      body = %{"jsonrpc" => "2.0", "method" => "ping", "id" => 1}
      %{conn: conn, path: "/mcp/messages?session_id=#{session_id}", body: body}
    end

    test "rejects a foreign Host (DNS rebinding)", %{conn: conn, path: path, body: body} do
      conn = post(%{conn | host: "evil.example.com"}, path, body)
      assert response(conn, 403)
      refute_received {:mcp_response, _}
    end

    test "rejects a foreign Origin", %{conn: conn, path: path, body: body} do
      conn = conn |> put_req_header("origin", "https://evil.example.com") |> post(path, body)
      assert response(conn, 403)
      refute_received {:mcp_response, _}
    end

    test "accepts native clients without Origin and every local host", ctx do
      assert ctx.conn |> post(ctx.path, ctx.body) |> response(202)

      for host <- ["127.0.0.1", "[::1]", "localhost"] do
        assert response(post(%{ctx.conn | host: host}, ctx.path, ctx.body), 202)
      end
    end

    test "accepts local origins including the Tauri webview", ctx do
      origins = [
        "http://localhost:4000",
        "http://127.0.0.1:4000",
        "tauri://localhost",
        "http://[::1]:4000"
      ]

      for origin <- origins do
        assert ctx.conn
               |> put_req_header("origin", origin)
               |> post(ctx.path, ctx.body)
               |> response(202)
      end
    end

    test "SSE rejects a foreign Origin", %{conn: conn} do
      conn = conn |> put_req_header("origin", "http://evil.test") |> get("/mcp/sse")
      assert response(conn, 403)
    end

    test "SSE no longer sends a wildcard CORS header", %{conn: conn} do
      task = Task.async(fn -> get(conn, "/mcp/sse") end)
      pid = wait_for_session_other_than_self()
      send(pid, :close)

      assert Task.await(task).resp_headers |> List.keyfind("access-control-allow-origin", 0) ==
               nil
    end

    defp wait_for_session_other_than_self(attempts \\ 50) do
      me = self()

      case Registry.select(Trenino.MCP.SessionRegistry, [{{:_, :"$1", :_}, [], [:"$1"]}])
           |> Enum.reject(&(&1 == me)) do
        [pid | _] ->
          pid

        [] when attempts > 0 ->
          Process.sleep(10)
          wait_for_session_other_than_self(attempts - 1)
      end
    end
  end

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
      assert length(tools) == 66
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

  describe "Streamable HTTP POST /mcp" do
    test "answers a request in the response body", %{conn: conn} do
      conn =
        post(conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{"protocolVersion" => "2025-06-18"}
        })

      assert %{"id" => 1, "result" => result} = json_response(conn, 200)
      assert result["protocolVersion"] == "2025-06-18"
      assert result["serverInfo"]["name"] == "Trenino"
    end

    test "returns tools/call results", %{conn: conn} do
      conn =
        post(conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 2,
          "method" => "tools/call",
          "params" => %{"name" => "list_trains", "arguments" => %{}}
        })

      assert %{"result" => %{"content" => [%{"text" => text}]}} = json_response(conn, 200)
      assert %{"trains" => []} = Jason.decode!(text)
    end

    test "returns JSON-RPC errors in the body", %{conn: conn} do
      conn = post(conn, "/mcp", %{"jsonrpc" => "2.0", "id" => 3, "method" => "nope"})
      assert %{"id" => 3, "error" => %{"code" => -32_601}} = json_response(conn, 200)
    end

    test "accepts notifications and client responses with 202", %{conn: conn} do
      notification = %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}
      assert conn |> post("/mcp", notification) |> response(202) == ""

      client_response = %{"jsonrpc" => "2.0", "id" => 7, "result" => %{}}
      assert conn |> post("/mcp", client_response) |> response(202) == ""
    end

    test "rejects id-less requests instead of running them blind", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "params" => %{"name" => "list_trains", "arguments" => %{}}
      }

      assert %{"error" => %{"code" => -32_600}} =
               conn |> post("/mcp", message) |> json_response(400)
    end

    test "rejects batches and malformed bodies", %{conn: conn} do
      batch = conn |> put_req_header("content-type", "application/json") |> post("/mcp", "[]")
      assert %{"error" => %{"code" => -32_600}} = json_response(batch, 400)

      assert %{"error" => %{"code" => -32_600}} =
               conn |> post("/mcp", %{"foo" => "bar"}) |> json_response(400)
    end

    test "GET and DELETE are not allowed", %{conn: conn} do
      for conn <- [get(conn, "/mcp"), delete(conn, "/mcp")] do
        assert response(conn, 405)
        assert get_resp_header(conn, "allow") == ["POST"]
      end
    end

    test "rejects a foreign Origin", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "https://evil.example.com")
        |> post("/mcp", %{"jsonrpc" => "2.0", "id" => 1, "method" => "ping"})

      assert response(conn, 403)
    end
  end
end
