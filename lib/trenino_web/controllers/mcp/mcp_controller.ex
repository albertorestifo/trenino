defmodule TreninoWeb.MCP.MCPController do
  @moduledoc """
  Phoenix controller for MCP SSE transport.

  Exposes two endpoints:
  - GET /mcp/sse — Opens an SSE stream and sends the POST endpoint URL
  - POST /mcp/messages — Receives JSON-RPC messages and pushes responses via SSE
  """

  use TreninoWeb, :controller

  alias Trenino.MCP.Server

  @doc """
  Opens an SSE stream. Sends an `endpoint` event with the POST URL
  and a session ID, then keeps the connection open for responses.
  """
  def sse(conn, _params) do
    session_id = generate_session_id()
    {:ok, _} = Registry.register(Trenino.MCP.SessionRegistry, session_id, self())

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("access-control-allow-origin", "*")
      |> send_chunked(200)

    messages_url = url(conn, ~p"/mcp/messages?session_id=#{session_id}")
    send_sse_event(conn, "endpoint", messages_url)

    sse_loop(conn)
  end

  @doc """
  Receives JSON-RPC messages from the MCP client and pushes
  responses through the corresponding SSE stream.
  """
  def messages(conn, %{"session_id" => session_id} = params) do
    body = Map.drop(params, ["session_id"])

    case Registry.lookup(Trenino.MCP.SessionRegistry, session_id) do
      [{pid, _}] ->
        case Server.handle_message(body) do
          {:reply, response} ->
            send(pid, {:mcp_response, response})
            send_resp(conn, 202, "accepted")

          {:error, response} ->
            send(pid, {:mcp_response, response})
            send_resp(conn, 202, "accepted")
        end

      [] ->
        conn |> put_status(404) |> json(%{error: "Session not found"})
    end
  end

  def messages(conn, _params) do
    conn |> put_status(400) |> json(%{error: "session_id parameter required"})
  end

  defp sse_loop(conn) do
    receive do
      {:mcp_response, response} ->
        case send_sse_event(conn, "message", Jason.encode!(response)) do
          {:ok, conn} -> sse_loop(conn)
          {:error, _reason} -> conn
        end

      :close ->
        conn
    end
  end

  defp send_sse_event(conn, event, data) do
    payload = "event: #{event}\ndata: #{data}\n\n"
    chunk(conn, payload)
  end

  defp generate_session_id do
    Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
  end
end
