defmodule TreninoWeb.EndpointLocalOnlyTest do
  use TreninoWeb.ConnCase, async: false

  test "the UI rejects a rebound Host before reaching the router", %{conn: conn} do
    assert conn |> Map.put(:host, "evil.example.com") |> get("/") |> response(403)
  end

  test "the UI rejects a foreign Origin", %{conn: conn} do
    conn = conn |> put_req_header("origin", "https://evil.example.com") |> get("/")
    assert response(conn, 403)
  end

  test "POST /api/shutdown is also local only", %{conn: conn} do
    assert conn |> Map.put(:host, "evil.example.com") |> post("/api/shutdown") |> response(403)
  end

  test "health stays reachable with any Host", %{conn: conn} do
    conn = conn |> Map.put(:host, "evil.example.com") |> get("/api/health")
    refute conn.status == 403
  end

  test "browser, Tauri and loopback hosts still load the UI", %{conn: conn} do
    for {host, origin} <- [
          {"localhost", nil},
          {"127.0.0.1", "http://127.0.0.1:4000"},
          {"[::1]", nil},
          {"localhost", "http://localhost:4000"},
          {"localhost", "tauri://localhost"},
          {"tauri.localhost", "http://tauri.localhost"}
        ] do
      conn = %{conn | host: host}
      conn = if origin, do: put_req_header(conn, "origin", origin), else: conn
      assert get(conn, "/").status == 200, "#{host} #{origin}"
    end
  end

  describe "websocket origin" do
    defp upgrade(conn, origin) do
      conn
      |> put_req_header("origin", origin)
      |> put_req_header("connection", "upgrade")
      |> put_req_header("upgrade", "websocket")
      |> put_req_header("sec-websocket-version", "13")
      |> put_req_header("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ==")
      |> get("/live/websocket?vsn=2.0.0")
    end

    test "rejects foreign origins even with a local Host header", %{conn: conn} do
      assert upgrade(conn, "https://evil.example.com").status == 403
    end

    test "accepts local origins on any port", %{conn: conn} do
      for origin <- ["http://localhost:4000", "http://127.0.0.1:1234", "tauri://localhost"] do
        refute upgrade(conn, origin).status == 403, origin
      end
    end

    test "check_origin config lists only local hosts" do
      origins = Application.fetch_env!(:trenino, TreninoWeb.Endpoint)[:check_origin]
      assert is_list(origins)
      pattern = ~r{^//(localhost|127\.0\.0\.1|\[::1\]|tauri\.localhost)$}
      assert Enum.all?(origins, &String.match?(&1, pattern))
    end
  end
end
