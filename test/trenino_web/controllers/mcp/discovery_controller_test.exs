defmodule TreninoWeb.MCP.DiscoveryControllerTest do
  use TreninoWeb.ConnCase, async: true

  setup %{conn: conn}, do: %{conn: %{conn | host: "localhost"}}

  describe "GET /llms.txt" do
    test "explains how to install the server for each client", %{conn: conn} do
      conn = get(conn, "/llms.txt")
      body = response(conn, 200)

      assert response_content_type(conn, :markdown) =~ "text/markdown"
      assert body =~ "claude mcp add --transport http --scope user trenino http://localhost"
      assert body =~ "codex mcp add trenino --url http://localhost"
      assert body =~ "mcp-remote"
      assert body =~ "/mcp/sse"
    end

    test "rejects a foreign Host", %{conn: conn} do
      assert conn |> Map.put(:host, "evil.example.com") |> get("/llms.txt") |> response(403)
    end
  end

  describe "GET /mcp/server-card" do
    test "describes both transports", %{conn: conn} do
      conn = get(conn, "/mcp/server-card")
      card = conn |> response(200) |> Jason.decode!()

      assert response_content_type(conn, :json) =~ "application/mcp-server-card+json"
      assert card["name"] == "io.github.albertorestifo/trenino"
      assert is_binary(card["version"])

      assert [
               %{"type" => "streamable-http", "url" => streamable_url} = streamable,
               %{"type" => "sse", "url" => sse_url} = sse
             ] = card["remotes"]

      assert streamable_url =~ ~r{^http://localhost(:\d+)?/mcp$}
      assert sse_url =~ ~r{/mcp/sse$}
      assert "2025-06-18" in streamable["supportedProtocolVersions"]
      assert sse["supportedProtocolVersions"] == streamable["supportedProtocolVersions"]
      assert card["title"] == "Trenino"
    end
  end

  describe "GET /.well-known/ai-catalog.json" do
    test "links the server card", %{conn: conn} do
      conn = get(conn, "/.well-known/ai-catalog.json")
      catalog = conn |> response(200) |> Jason.decode!()

      assert response_content_type(conn, :json) =~ "application/ai-catalog+json"

      assert [%{"type" => "application/mcp-server-card+json", "url" => url}] =
               catalog["entries"]

      assert url =~ ~r{/mcp/server-card$}
    end
  end
end
