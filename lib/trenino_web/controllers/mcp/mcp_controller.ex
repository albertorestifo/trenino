defmodule TreninoWeb.MCP.MCPController do
  @moduledoc """
  Phoenix controller for the MCP transports.

  Streamable HTTP (current spec, stateless, JSON responses only):
  - POST /mcp — Receives one JSON-RPC message and answers in the response body
  - GET /mcp — 405, the server never opens a server-initiated stream

  Legacy HTTP+SSE (protocol 2024-11-05):
  - GET /mcp/sse — Opens an SSE stream and sends the POST endpoint URL
  - POST /mcp/messages — Receives JSON-RPC messages and pushes responses via SSE
  """

  use TreninoWeb, :controller

  alias Trenino.MCP.Server

  @doc """
  Streamable HTTP endpoint. Requests get their JSON-RPC response as the body;
  notifications and client responses (no `method` with an `id`) get 202.
  Batches are not supported.
  """
  def streamable(conn, %{"_json" => _batch}) do
    conn |> put_status(400) |> json(invalid_request())
  end

  def streamable(conn, %{"method" => _, "id" => _} = message) do
    {_, response} = Server.handle_message(message)
    json(conn, response)
  end

  def streamable(conn, %{"jsonrpc" => "2.0"} = message) do
    _ = Server.handle_message(message)
    send_resp(conn, 202, "")
  end

  def streamable(conn, _params) do
    conn |> put_status(400) |> json(invalid_request())
  end

  @doc """
  The server never pushes messages outside a request, so there is no stream to open.
  """
  def streamable_get(conn, _params) do
    conn
    |> put_resp_header("allow", "POST")
    |> send_resp(405, "")
  end

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

  defp invalid_request do
    %{jsonrpc: "2.0", id: nil, error: %{code: -32_600, message: "Invalid request"}}
  end

  defp generate_session_id do
    Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
  end
end
